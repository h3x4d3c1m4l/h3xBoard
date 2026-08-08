# Building CPython for WebAssembly

The Python Lab widget runs **one** Python build on every platform: CPython
compiled for `wasm32-wasi`. Only the *host* that executes it changes — the
browser's own WebAssembly engine on web, a Rust interpreter on iOS and Android.
One artifact means one Python version, one standard library and one set of error
messages, so a program a pupil runs in a browser behaves identically to the same
program on a teacher's iPad.

This document is how that artifact is produced. Run `./tool/build_python_wasm.sh`
to do it; read on for why each step is the way it is.

## Why not Pyodide

Pyodide is the obvious candidate and it does not work here. It is CPython built
with **Emscripten**, so its `.wasm` imports a *JavaScript* runtime rather than
WASI: a JS-implemented virtual filesystem, `invoke_*` trampolines for
setjmp/longjmp, and `emscripten_asm_const`, which evaluates JavaScript strings
embedded in the binary. Standalone runtimes — wasmtime, wasmer, wasmi — provide
WASI, not that. Hosting Pyodide outside a browser would mean reimplementing
Emscripten's runtime *and* shipping a JS engine.
[The Pyodide maintainers say the same](https://github.com/pyodide/pyodide/discussions/5145):
it "can only run in a browser or Node.js", and WASI support is not planned.

A `wasm32-wasi` build has no such problem, and since CPython 3.13 WASI is a
**Tier-2 platform** with upstream CI, so this is a supported configuration rather
than a hack.

## Why we build it rather than download one

[VMware's Wasm Language Runtimes](https://github.com/vmware-labs/webassembly-language-runtimes)
publishes prebuilt `python.wasm` files and they work fine — but the project is
dormant: last commit June 2024, last Python release **December 2023 (3.12.0)**.
Building it ourselves gets a current, patchable Python, and it is about fifteen
minutes of compute.

## Prerequisites

| | |
|---|---|
| **wasi-sdk 24** | Downloaded automatically by the script. **Not the latest.** Each CPython release is tested against one specific SDK; 3.14.7 wants 24, and `Tools/wasm` prints `⚠️ Found WASI SDK 33, but WASI SDK 24 is the supported version` for anything else. |
| **Python 3.11+** on the host | Only to *run* the build script — CPython cross-compiles by first building a host interpreter from the same source. But `Tools/wasm` uses `contextlib.chdir`, which is 3.11+, and **macOS still ships 3.9**. `brew install python@3.14`. |
| **pkg-config**, Xcode CLT / build-essential | `brew install pkg-config` |
| **wasmtime** (optional) | For verifying the result locally. `brew install wasmtime` |

## What the build does

```bash
./tool/build_python_wasm.sh            # writes into assets/python/
```

1. Downloads wasi-sdk 24 and the CPython source into `.python-wasm-build/`.
2. Runs `python3.14 Tools/wasm/wasi build`, which compiles CPython **twice** —
   once for the host (needed to cross-compile) and once for `wasm32-wasip1`.
3. Strips the result and packs the standard library.

Output, both committed as Flutter assets:

| file | size | gzipped |
|---|---|---|
| `assets/python/python.wasm` | 7.3 MB | 2.2 MB |
| `assets/python/python314.zip` | 12 MB | 4.1 MB |

## The three things that are easy to get wrong

**Strip the binary.** CPython's WASI build compiles with `-g` and the debug info
is roughly three quarters of the output — **29 MB before stripping, 7.3 MB
after**. Nothing at runtime reads it.

**The stdlib zip must be _stored_, not deflated.** This build has no zlib; it is
not among the 79 built-in modules, because zlib would have to be cross-compiled
for WASI separately. So `zipimport` cannot inflate a compressed entry and fails
with `can't decompress data; zlib not available`. `zip -0` sidesteps it entirely,
and costs little in practice because the `.py` text compresses in transit anyway.

**`max-wasm-stack` must be raised to 16 MB.** CPython overflows the default WASM
stack during interpreter startup. The wrapper CPython generates
(`cross-build/wasm32-wasip1/python.sh`) sets `--wasm max-wasm-stack=16777216`, and
**both hosts must do the same** — the browser instantiation and the Rust runtime
alike. Symptom if missed: a stack-exhaustion trap before any Python code runs.

## Running it

```bash
wasmtime run --wasm max-wasm-stack=16777216 \
  --dir assets/python::/py \
  --env PYTHONPATH=/py/python314.zip --env PYTHONHOME=/py \
  assets/python/python.wasm -c "print(1 + 1)"
```

Note there is **no `--` before the Python arguments**; wasmtime passes everything
after the module straight through, and `--` makes Python read `-c` as a filename.

## What this Python can and cannot do

Verified present: `math`, `json`, `re`, `random`, `datetime`, `itertools`,
`collections`, `_socket`, and the rest of the pure-Python standard library.
Tracebacks are full quality, including the 3.11+ caret markers:

```
  File "<string>", line 1, in <module>
    1/0
    ~^~
ZeroDivisionError: division by zero
```

`input()` reads stdin normally, which is what the widget's input box feeds.

Absent: **zlib** and **_ssl**, so `gzip`, `zipfile`-on-compressed-archives and
anything TLS will not work. Neither matters for teaching, and both could be added
later by cross-compiling the C libraries for WASI and reconfiguring.

The build is also a genuine sandbox, and that is worth preserving: a WASM module
can only touch what the host grants it. Preopening just the stdlib directory means
pupil code has no filesystem, no network and no way out. **Do not preopen more
than `assets/python`.**

## Upgrading Python

Bump `PYTHON_VERSION` in `tool/build_python_wasm.sh` — and check which wasi-sdk
that release tests against, bumping `WASI_SDK_VERSION` with it. The two are a
matched pair. Then rebuild, re-run the widget tests, and confirm the stdlib zip
name in `pubspec.yaml` still matches.
