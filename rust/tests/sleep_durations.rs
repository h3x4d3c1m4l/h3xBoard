//! Sleeps of several lengths, through the real interpreter.
//!
//! `sleep_actually_sleeps` in python_runs.rs only covers 0.3s. This covers the
//! lengths a lesson actually uses, because a host that gets the deadline
//! arithmetic subtly wrong can be right for one duration and wrong for another.

#![cfg(python_runtime)]

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use h3xboard_rust::python;

fn assets() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../assets/python")
}

#[test]
fn sleeps_of_several_lengths_all_finish() {
    let wasm = std::fs::read(assets().join("python.wasm")).expect("python.wasm is an asset");
    let stdlib =
        Arc::new(std::fs::read(assets().join("python314.zip")).expect("the stdlib is an asset"));
    let (engine, module) = python::compile(&wasm).expect("the shipped interpreter translates");

    let started = Instant::now();
    let outcome = python::run(
        &engine,
        &module,
        stdlib,
        concat!(
            "import time\n",
            "for d in (0.3, 1, 2):\n",
            "    s = time.time()\n",
            "    time.sleep(d)\n",
            "    print(d, '->', round(time.time() - s, 2), flush=True)\n",
        ),
        "",
        Arc::new(AtomicBool::new(false)),
    );
    let elapsed = started.elapsed();

    println!("--- stdout ---\n{}", outcome.stdout);
    println!("--- stderr ---\n{}", outcome.stderr);
    println!("wall clock: {elapsed:?}");

    assert_eq!(outcome.exit_code, 0, "stderr was: {}", outcome.stderr);
    assert!(outcome.stdout.contains("0.3 -> 0.3"), "{}", outcome.stdout);
    assert!(outcome.stdout.contains("1 -> 1.0"), "{}", outcome.stdout);
    assert!(outcome.stdout.contains("2 -> 2.0"), "{}", outcome.stdout);
}

#[test]
fn stop_interrupts_a_sleeping_program() {
    // Stop used to be unable to touch a sleeping program at all. The run loop
    // only checks for cancellation between fuel slices, and a program parked
    // inside poll_oneoff never produces one — so `time.sleep(600)` was ten
    // minutes with no way out but killing the app.
    let wasm = std::fs::read(assets().join("python.wasm")).expect("python.wasm is an asset");
    let stdlib =
        Arc::new(std::fs::read(assets().join("python314.zip")).expect("the stdlib is an asset"));
    let (engine, module) = python::compile(&wasm).expect("the shipped interpreter translates");

    let cancel = Arc::new(AtomicBool::new(false));
    let flag = Arc::clone(&cancel);
    std::thread::spawn(move || {
        std::thread::sleep(std::time::Duration::from_secs(2));
        flag.store(true, Ordering::Relaxed);
    });

    let started = Instant::now();
    let outcome = python::run(
        &engine,
        &module,
        stdlib,
        "import time\nprint('sleeping', flush=True)\ntime.sleep(600)\nprint('never')\n",
        "",
        cancel,
    );
    let elapsed = started.elapsed();

    assert_eq!(outcome.exit_code, 130, "stderr was: {}", outcome.stderr);
    assert!(outcome.stdout.contains("sleeping"), "{}", outcome.stdout);
    assert!(
        !outcome.stdout.contains("never"),
        "the sleep must not have finished"
    );
    assert!(
        elapsed < Duration::from_secs(30),
        "Stop took {elapsed:?} against a 600s sleep",
    );
}
