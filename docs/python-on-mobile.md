# Running Python on iOS and Android

The Code Playground runs the *same* `python.wasm` everywhere. Only the thing that
executes it differs: the browser's own WebAssembly engine on the web, and
[wasmi](https://github.com/wasmi-labs/wasmi) — a WebAssembly interpreter written
in Rust — on a phone. One interpreter build, one standard library, one set of
error messages.

For how `python.wasm` itself is produced, see
[python-wasm-build.md](python-wasm-build.md).

## Why an interpreter, and why this one

A phone cannot JIT. iOS forbids it outright for App Store apps, so anything that
compiles WebAssembly to machine code at runtime is off the table regardless of
how fast it is.

That leaves interpreters, and the two candidates were wasmi and Wasmtime's
portable backend, Pulley. Measured on this project's own `python.wasm`, best of
five runs on an M-series Mac:

| program | Wasmtime / Cranelift (JIT) | Wasmtime / Pulley | wasmi |
| --- | --- | --- | --- |
| startup (`pass`) | 153 ms | 555 ms | **329 ms** |
| fizzbuzz 2k + sieve 20k | 156 ms | 612 ms | **367 ms** |
| 100 000-iteration loop | 167 ms | 876 ms | **520 ms** |
| 1 000 000-iteration loop | 291 ms | 3600 ms | **2453 ms** |

Cranelift is far ahead, and irrelevant: it is the JIT we are not allowed to use.
Between the two interpreters wasmi wins by roughly 1.4x, and the gap is if
anything understated — Wasmtime's compilation cache was warmed before timing,
while wasmi's translation is paid inside every number above.

Android *does* permit JIT, so Wasmtime with Cranelift would genuinely be several
times quicker there. It is not worth it: two engines mean two sets of behaviour
to keep identical, plus roughly 20 MB of Cranelift per ABI, to speed up the one
thing a classroom rarely does. A tight million-iteration loop is the outlier —
the fizzbuzz-and-sieve row is 367 ms end to end, of which 329 ms is CPython
starting up.

wasmi also settles the Stop button. `while True: pass` calls no host function, so
nothing outside the interpreter can interrupt it; wasmi meters execution with
fuel and can *resume* a call that ran out, so the run is sliced and the cancel
flag checked between slices.

## Layout

```text
rust/
  build.rs              # derives the `python_runtime` cfg (see below)
  src/
    api/python.rs       # the four functions Dart can call
    session.rs          # holds the translated interpreter between calls
    python/
      mod.rs            # engine setup, the fuel/cancel loop, output collection
      wasi.rs           # the WASI preview1 host — a port of web/python/wasi.js
  tests/python_runs.rs  # runs real programs through the real interpreter

lib/services/python/
  python_runtime.dart       # the interface, and a three-clause conditional import
  python_runtime_web.dart   # dart.library.js_interop -> the worker
  python_runtime_io.dart    # dart.library.io -> a runtime Platform check
  native_python_runtime.dart# the Rust-backed host
  python_runtime_stub.dart  # everything else: says why, stays usable
```

`wasi.rs` is a port of `web/python/wasi.js`, function for function and errno for
errno. **The JS file is the reference.** Where they disagree, the Rust is wrong —
a program that behaves differently on a phone than on the projector defeats the
point of shipping one interpreter.

## How iOS and Android get the interpreter, and nothing else does

Two mechanisms, because neither alone can express it:

- **cargokit never passes `--features` to cargo.** Grep `rust_builder/` — the
  word does not appear, and `cargokit.yaml` has no per-platform key. So a cargo
  feature is all-targets or no-targets, and could not mean "mobile only".
- Instead the interpreter arrives through a **target-gated dependency table** in
  `rust/Cargo.toml`, which cargo resolves from the `--target` cargokit always
  passes.
- The `python-runtime` **feature** still exists, for host builds: `just test-rust`
  turns it on so a development machine compiles and exercises the same code.

`build.rs` folds both routes into a single `python_runtime` cfg, so the source
never has to know which one applied. A `compile_error!` in `lib.rs` fails any iOS
or Android build where the two have drifted apart — without it, losing the
interpreter would be silent: the app would build, ship, and tell a classroom that
running Python is not available.

The web bundle gets none of this. `rust_builder` declares no web platform, and
the Dart side keeps the bridge behind `dart.library.io`, so `flutter build web`
never compiles a WebAssembly interpreter to run inside a WebAssembly interpreter.
The generated web bindings exist and are kept working, ready if Rust is ever
wanted there for something else.

## Building and testing

```bash
just test-rust                 # real programs through the real interpreter
just lint-rust                 # clippy -D warnings, plus rustfmt --check
just check-rust-targets        # host without the interpreter, and iOS with it
just gen-rust                  # regenerate the Dart bindings after api/ changes
```

Homebrew's rustup keeps its shims out of `PATH`; add them first:

```bash
export PATH="$HOME/.cargo/bin:/opt/homebrew/opt/rustup/bin:$PATH"
```

Targets, once per machine:

```bash
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
rustup target add aarch64-linux-android armv7-linux-androideabi \
                  i686-linux-android x86_64-linux-android
```

Android additionally needs the NDK's clang, which `flutter build` supplies from
the SDK. Building for an Android target with bare `cargo` fails in `dart-sys` —
a flutter_rust_bridge dependency with a C build step, not anything of ours —
unless the NDK toolchain is on `PATH`.

## What the host guarantees

The tests in `rust/tests/python_runs.rs` are the specification, and each one
exists because the failure it rules out is worse than a program not working:

- A traceback names `/main.py` and quotes the offending line. The program is
  written to a file and run as one, rather than passed with `-c`, purely for this.
  It survives the stdlib being shipped as bytecode, because the pupil's own
  program is still source.
- Output is capped at 256 KiB per stream and says when it was cut, matching
  `python_worker.js`. Output is mirrored to other screens and saved with the
  board, so a runaway `print` must not grow the board file without bound.
- `while True: pass` stops when Stop is pressed.
- Runaway recursion with CPython's own guard removed traps cleanly rather than
  overflowing a native stack and taking the whole app down.
- A runaway allocation becomes a catchable `MemoryError` rather than an OOM kill,
  because guest memory is capped and a refused grow returns -1 rather than
  trapping.
- There is no host filesystem and no network. Not a permission check — the host
  has nothing else to hand out, because a wasm module can only reach what its
  imports allow.
