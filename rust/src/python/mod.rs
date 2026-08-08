//! Runs CPython, compiled to `wasm32-wasi`, on top of wasmi.
//!
//! The web build hands the same `python.wasm` to the browser's own engine and
//! drives it from `web/python/python_worker.js`. This module is that worker's
//! opposite number: same artifact, same argv, same environment, same virtual
//! filesystem, same output cap — so a program produces byte-identical output on
//! a phone and in a browser. That equality is the entire reason for shipping one
//! interpreter instead of one per platform.
//!
//! Why wasmi and not wasmtime: iOS forbids JIT, so wasmtime would fall back to
//! its Pulley interpreter there, which benchmarks ~1.4x slower than wasmi on
//! this workload. See docs/python-wasm-build.md.

mod wasi;

use std::collections::BTreeMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Instant;

use wasmi::{Config, Engine, Linker, Module, ResumableCall, Store};

use wasi::{ProcExit, WasiCtx};

/// Per-stream output cap, matching `MAX_OUTPUT_BYTES` in python_worker.js.
const MAX_OUTPUT_BYTES: usize = 256 * 1024;

/// Ceiling on wasmi's value stack, counted in 8-byte slots — *not* bytes,
/// whatever the doc comment on the setter says: `Stack::new` feeds this straight
/// into a `Vec<UntypedVal>`. 2 Mi slots is the 16 MiB the web build asks for via
/// `--max-wasm-stack`. Grown lazily, so it costs nothing until it is needed.
const MAX_STACK_HEIGHT: usize = 2 * 1024 * 1024;

/// Wasm call frames. Independent of [`MAX_STACK_HEIGHT`], and the knob that
/// actually mimics `--max-wasm-stack`: wasmi's default of 1000 is low enough
/// that `x = ((((...))))` nested 60 deep traps with "call stack exhausted"
/// before CPython's own parser guard can report it properly.
const MAX_RECURSION_DEPTH: usize = 20_000;

/// How much fuel to hand out before looking up to see whether Stop was pressed.
///
/// This is the whole cancellation mechanism. `while True: pass` calls no host
/// function, so nothing else would ever get a look in; running on a fuel budget
/// and resuming is what makes the button work. Small enough that Stop feels
/// immediate, large enough that the check is lost in the noise — a slice is a
/// few milliseconds of interpretation.
const FUEL_SLICE: u64 = 20_000_000;

/// How far the guest may grow its linear memory. CPython starts at 40 MiB and
/// grows on demand; without a ceiling a runaway allocation walks all the way to
/// the wasm32 limit and the OS kills the app. A refused grow surfaces as a
/// normal Python `MemoryError` instead.
const MAX_GUEST_MEMORY: usize = 256 * 1024 * 1024;

/// The program is written here, and this is the path CPython is told to run, so
/// a traceback names a file the pupil recognises and quotes the offending line.
const PROGRAM_PATH: &str = "/main.py";

/// Where the standard library zip is mounted. Must match `PYTHONPATH`.
const STDLIB_PATH: &str = "/python314.zip";

pub struct Outcome {
    pub stdout: String,
    pub stderr: String,
    pub exit_code: i32,
    pub truncated: bool,
    pub duration_ms: u64,
}

impl Outcome {
    fn failure(message: impl Into<String>, started: Instant) -> Self {
        Outcome {
            stdout: String::new(),
            stderr: message.into(),
            exit_code: 1,
            truncated: false,
            duration_ms: started.elapsed().as_millis() as u64,
        }
    }
}

/// Translates `python.wasm` once. Both halves are cheap to clone and are held
/// for the app's lifetime, so a run never pays for this again.
pub fn compile(wasm: &[u8]) -> Result<(Engine, Module), wasmi::Error> {
    let mut config = Config::default();
    config.consume_fuel(true);
    config.set_max_stack_height(MAX_STACK_HEIGHT);
    config.set_max_recursion_depth(MAX_RECURSION_DEPTH);

    // Eager, and not the default `LazyTranslation`, because lazy translation is
    // not sound in combination with `call_resumable`: a function translated
    // while a resumable call is suspended leaves the suspended frame's
    // instruction pointer dangling, and resuming it reads from freed memory.
    // The symptom is an intermittent SIGBUS/SIGSEGV inside `execute_instrs`,
    // and it gets more likely the smaller FUEL_SLICE is — i.e. exactly when
    // Stop is made more responsive. Costs ~60 ms once, at load.
    config.compilation_mode(wasmi::CompilationMode::Eager);

    let engine = Engine::new(&config);
    let module = Module::new(&engine, wasm)?;
    Ok((engine, module))
}

/// Runs `code` to completion, feeding `stdin` to `input()`.
///
/// Never returns `Err` for a *program* error: a traceback comes back in
/// `stderr` with a non-zero exit code, because a pupil's mistake is a normal
/// outcome here rather than an exceptional one. `cancel` is polled between fuel
/// slices; when it is set the run stops and reports exit code 130, the shell
/// convention for "interrupted".
pub fn run(
    engine: &Engine,
    module: &Module,
    stdlib: Arc<Vec<u8>>,
    code: &str,
    stdin: &str,
    cancel: &AtomicBool,
) -> Outcome {
    let started = Instant::now();

    let mut files: BTreeMap<String, Arc<Vec<u8>>> = BTreeMap::new();
    files.insert(STDLIB_PATH.to_owned(), stdlib);
    files.insert(PROGRAM_PATH.to_owned(), Arc::new(code.as_bytes().to_vec()));

    let ctx = WasiCtx::new(
        // Running a file rather than `-c` so a traceback names /main.py and
        // quotes the line, which is most of the teaching value.
        &["python", PROGRAM_PATH],
        &[
            ("PYTHONHOME", "/"),
            ("PYTHONPATH", STDLIB_PATH),
            ("PYTHONDONTWRITEBYTECODE", "1"),
            ("PYTHONUNBUFFERED", "1"),
        ],
        files,
        stdin.as_bytes().to_vec(),
        MAX_OUTPUT_BYTES,
        MAX_GUEST_MEMORY,
    );

    let mut store = Store::new(engine, ctx);
    store.limiter(|ctx| &mut ctx.limits);
    let mut linker = Linker::new(engine);
    if let Err(error) = wasi::add_to_linker(&mut linker) {
        return Outcome::failure(format!("Could not prepare the sandbox: {error}"), started);
    }

    if let Err(error) = store.set_fuel(FUEL_SLICE) {
        return Outcome::failure(format!("Could not meter the interpreter: {error}"), started);
    }

    // Instantiation runs CPython's data segment setup, which is why it needs
    // fuel too — and why it is inside the cancellable region below.
    let instance = match linker.instantiate_and_start(&mut store, module) {
        Ok(instance) => instance,
        Err(error) => return finish(store, exit_code_of(&error, 1), started, describe(&error)),
    };

    let Some(start) = instance.get_func(&store, "_start") else {
        return Outcome::failure("The interpreter has no entry point.", started);
    };

    let mut call = match start.call_resumable(&mut store, &[], &mut []) {
        Ok(call) => call,
        Err(error) => return finish(store, exit_code_of(&error, 1), started, describe(&error)),
    };

    loop {
        match call {
            ResumableCall::Finished => return finish(store, 0, started, None),
            ResumableCall::OutOfFuel(invocation) => {
                if cancel.load(Ordering::Relaxed) {
                    return finish(store, 130, started, Some("Stopped.".to_owned()));
                }
                let refill = invocation.required_fuel().max(FUEL_SLICE);
                if let Err(error) = store.set_fuel(refill) {
                    return finish(store, 1, started, Some(error.to_string()));
                }
                match invocation.resume(&mut store, &mut []) {
                    Ok(next) => call = next,
                    Err(error) => {
                        return finish(store, exit_code_of(&error, 1), started, describe(&error))
                    }
                }
            }
            // No host function here returns a resumable error — proc_exit is the
            // only one that traps, and it means the program is over.
            ResumableCall::HostTrap(trap) => {
                let error = trap.into_host_error();
                return finish(store, exit_code_of(&error, 1), started, describe(&error));
            }
        }
    }
}

/// A `proc_exit` trap is CPython finishing normally: `_start` never returns, so
/// this is how a clean exit arrives. Anything else is a real trap.
fn exit_code_of(error: &wasmi::Error, fallback: i32) -> i32 {
    error
        .downcast_ref::<ProcExit>()
        .map_or(fallback, |exit| exit.0)
}

/// The message to append to stderr, or `None` when the error was just
/// `proc_exit` — CPython has already printed its own traceback by then, and
/// adding "exit 1" underneath it would only be noise.
fn describe(error: &wasmi::Error) -> Option<String> {
    if error.downcast_ref::<ProcExit>().is_some() {
        None
    } else {
        Some(error.to_string())
    }
}

fn finish(
    store: Store<WasiCtx>,
    exit_code: i32,
    started: Instant,
    extra: Option<String>,
) -> Outcome {
    let ctx = store.into_data();
    let mut stderr = String::from_utf8_lossy(&ctx.stderr.bytes).into_owned();
    if let Some(extra) = extra {
        if !stderr.is_empty() && !stderr.ends_with('\n') {
            stderr.push('\n');
        }
        stderr.push_str(&extra);
    }

    Outcome {
        stdout: String::from_utf8_lossy(&ctx.stdout.bytes).into_owned(),
        stderr,
        exit_code,
        truncated: ctx.stdout.truncated || ctx.stderr.truncated,
        duration_ms: started.elapsed().as_millis() as u64,
    }
}
