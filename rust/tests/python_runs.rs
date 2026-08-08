//! Runs real programs through the real interpreter.
//!
//! The whole design rests on one claim — that a program behaves the same here as
//! it does in the browser — and the only way to keep that claim true is to run
//! the shipped `assets/python/python.wasm` against this host and check what comes
//! out. These tests are the mobile half of that; `web/python/wasi.js` is the
//! reference the expectations come from.
//!
//! Needs the interpreter: `cargo test --features python-runtime`, or `just
//! test-rust`. Without it the crate has no host to test.

#![cfg(python_runtime)]

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, OnceLock};
use std::thread;
use std::time::Duration;

use h3xboard_rust::python::{self, Outcome};

/// One interpreter at a time.
///
/// Cargo runs tests in parallel, and a dozen concurrent CPythons on one machine
/// turn a half-second startup into ten — which made the cancellation test race
/// its own timer and cancel during startup instead of inside the loop. Running
/// them one at a time is both faster overall and the only way that test can mean
/// what it says.
fn one_at_a_time() -> MutexGuard<'static, ()> {
    static LOCK: Mutex<()> = Mutex::new(());
    LOCK.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn assets() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../assets/python")
}

/// Translated once for the whole test binary: it is a 7.6 MB module, and paying
/// for it per test would dominate the run.
fn interpreter() -> &'static (wasmi::Engine, wasmi::Module) {
    static CELL: OnceLock<(wasmi::Engine, wasmi::Module)> = OnceLock::new();
    CELL.get_or_init(|| {
        let wasm = std::fs::read(assets().join("python.wasm")).expect("python.wasm is an asset");
        python::compile(&wasm).expect("the shipped interpreter translates")
    })
}

fn stdlib() -> Arc<Vec<u8>> {
    static CELL: OnceLock<Arc<Vec<u8>>> = OnceLock::new();
    Arc::clone(CELL.get_or_init(|| {
        Arc::new(std::fs::read(assets().join("python314.zip")).expect("the stdlib is an asset"))
    }))
}

fn run(code: &str) -> Outcome {
    run_with(code, "", &AtomicBool::new(false))
}

fn run_with(code: &str, stdin: &str, cancel: &AtomicBool) -> Outcome {
    let _serial = one_at_a_time();
    run_locked(code, stdin, cancel)
}

/// For a test that has already taken the lock and needs to do something between
/// taking it and starting the run.
fn run_locked(code: &str, stdin: &str, cancel: &AtomicBool) -> Outcome {
    let (engine, module) = interpreter();
    python::run(engine, module, stdlib(), code, stdin, cancel)
}

#[test]
fn prints_and_exits_cleanly() {
    let outcome = run("print('Hello, class!')\n");
    assert_eq!(outcome.stdout, "Hello, class!\n");
    assert_eq!(outcome.stderr, "");
    assert_eq!(outcome.exit_code, 0);
    assert!(!outcome.truncated);
}

#[test]
fn imports_from_the_standard_library_zip() {
    // The stdlib is a stored (uncompressed) zip because this build has no zlib;
    // if that ever regresses, zipimport fails and every import dies with it.
    let outcome = run("import json, math, random\nprint(json.dumps({'pi': round(math.pi, 2)}))\n");
    assert_eq!(outcome.stdout, "{\"pi\": 3.14}\n");
    assert_eq!(outcome.exit_code, 0);
}

#[test]
fn a_traceback_names_the_file_and_quotes_the_line() {
    // The single most valuable thing for a pupil, and the reason the program is
    // written to /main.py and run as a file rather than passed with -c.
    let outcome = run("x = 1\ny = x / 0\n");
    assert_eq!(outcome.exit_code, 1);
    assert!(
        outcome.stderr.contains("ZeroDivisionError"),
        "{}",
        outcome.stderr
    );
    assert!(outcome.stderr.contains("/main.py"), "{}", outcome.stderr);
    assert!(outcome.stderr.contains("line 2"), "{}", outcome.stderr);
    assert!(outcome.stderr.contains("y = x / 0"), "{}", outcome.stderr);
}

#[test]
fn a_syntax_error_is_reported_rather_than_crashing() {
    let outcome = run("def broken(:\n");
    assert_eq!(outcome.exit_code, 1);
    assert!(outcome.stderr.contains("SyntaxError"), "{}", outcome.stderr);
}

#[test]
fn input_reads_the_stdin_box_line_by_line() {
    let outcome = run_with(
        "name = input()\nage = int(input())\nprint(f'{name} is {age}')\n",
        "Sander\n41\n",
        &AtomicBool::new(false),
    );
    assert_eq!(outcome.stdout, "Sander is 41\n");
    assert_eq!(outcome.exit_code, 0);
}

#[test]
fn reading_past_the_end_of_stdin_raises_rather_than_hanging() {
    // Nothing can arrive later — stdin is a fixed buffer — so EOF must surface
    // as an error the pupil can see, not a wait that never ends.
    let outcome = run("input()\n");
    assert_eq!(outcome.exit_code, 1);
    assert!(outcome.stderr.contains("EOFError"), "{}", outcome.stderr);
}

#[test]
fn stdout_and_stderr_stay_separate() {
    let outcome = run("import sys\nprint('out')\nprint('err', file=sys.stderr)\n");
    assert_eq!(outcome.stdout, "out\n");
    assert!(outcome.stderr.contains("err"), "{}", outcome.stderr);
}

#[test]
fn runaway_output_is_capped_and_says_so() {
    // 256 KiB per stream, matching python_worker.js. Output is mirrored to other
    // screens and saved with the board, so it cannot be allowed to grow freely.
    let outcome = run("for i in range(200000):\n    print('x' * 40)\n");
    assert!(
        outcome.truncated,
        "a runaway printer must report truncation"
    );
    assert!(
        outcome.stdout.len() <= 256 * 1024,
        "got {} bytes",
        outcome.stdout.len()
    );
}

#[test]
fn an_endless_loop_stops_when_asked() {
    // The one thing fuel metering exists for: `while True: pass` calls no host
    // function, so nothing else would ever get a chance to interrupt it.
    // Take the lock before starting the timer. Started outside it, the delay is
    // spent queueing behind whichever test holds the lock, and the flag is
    // already set by the time this run begins — so it gets cancelled during
    // CPython's startup and never reaches the loop it is supposed to be testing.
    let _serial = one_at_a_time();

    let cancel = Arc::new(AtomicBool::new(false));
    let flag = Arc::clone(&cancel);
    thread::spawn(move || {
        thread::sleep(Duration::from_secs(2));
        flag.store(true, Ordering::Relaxed);
    });

    // flush=True because an interrupted program never gets to flush on the way
    // out: CPython block-buffers stdout when it is not a terminal, and it never
    // is here. Without the flush this would assert nothing about the loop.
    let outcome = run_locked(
        "print('looping', flush=True)\nwhile True:\n    pass\n",
        "",
        &cancel,
    );
    assert_eq!(outcome.exit_code, 130, "stderr was: {}", outcome.stderr);
    assert!(
        outcome.stdout.contains("looping"),
        "cancel must have interrupted the loop, not the startup before it"
    );
}

#[test]
fn the_sandbox_has_no_host_filesystem() {
    // Not a permission check — the host simply has nothing else to hand out. If
    // this ever starts passing a real path, the sandbox has been widened.
    let outcome = run("open('/etc/passwd')\n");
    assert_eq!(outcome.exit_code, 1);
    assert!(
        outcome.stderr.contains("FileNotFoundError") || outcome.stderr.contains("OSError"),
        "{}",
        outcome.stderr
    );
}

#[test]
fn the_sandbox_cannot_be_written_to() {
    let outcome = run("open('/scratch.txt', 'w')\n");
    assert_eq!(outcome.exit_code, 1);
    assert!(outcome.stderr.contains("Error"), "{}", outcome.stderr);
}

#[test]
fn sleep_actually_sleeps() {
    // time.sleep lands on poll_oneoff; a host that refuses it makes every
    // sleeping program die with "OSError: [Errno 58] Not supported".
    let outcome = run(
        "import time\nstart = time.time()\ntime.sleep(0.3)\nprint(round(time.time() - start, 1))\n",
    );
    assert_eq!(outcome.exit_code, 0, "stderr was: {}", outcome.stderr);
    assert_eq!(outcome.stdout.trim(), "0.3");
}

#[test]
fn runaway_recursion_is_contained_rather_than_taking_the_app_down() {
    // Ordinary runaway recursion raises RecursionError, because CPython's own
    // guard catches it first. This removes that guard, which is the case that
    // reaches the host: the wasm stack fills, and wasmi must trap rather than
    // overflow anything of ours. A native stack overflow here would abort the
    // whole app, not just the program a pupil is running.
    //
    // Slow (tens of seconds) by nature — it is filling a 16 MiB wasm stack, and
    // that ceiling is set to match the browser build rather than to be quick.
    let outcome = run(concat!(
        "import sys\n",
        "sys.setrecursionlimit(10**9)\n",
        "def f(n):\n",
        "    return f(n + 1)\n",
        "f(0)\n",
    ));
    assert_eq!(outcome.exit_code, 1);
    assert!(
        outcome.stderr.contains("call stack exhausted"),
        "expected a clean trap, got: {}",
        outcome.stderr
    );
}

#[test]
fn a_runaway_allocation_becomes_a_catchable_python_error() {
    // The guest's linear memory is capped, and the cap is deliberately *not* a
    // trap: a refused grow returns -1, which CPython's allocator turns into a
    // MemoryError the program can catch. Without the cap the guest walks up to
    // the wasm32 ceiling and the phone's OOM killer takes the whole app with it.
    let outcome = run(concat!(
        "blocks = []\n",
        "try:\n",
        "    while True:\n",
        "        blocks.append(bytearray(20_000_000))\n",
        "except MemoryError:\n",
        "    print('caught after', len(blocks), 'blocks')\n",
    ));
    assert_eq!(outcome.exit_code, 0, "stderr was: {}", outcome.stderr);
    assert!(
        outcome.stdout.starts_with("caught after"),
        "expected a catchable MemoryError, got: {:?} / {}",
        outcome.stdout,
        outcome.stderr
    );
}
