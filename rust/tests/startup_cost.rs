//! What the first Run actually costs, split into its two halves.
//!
//! Not an assertion so much as a measurement anyone can repeat: run it with
//! `--nocapture` under both profiles and compare. It exists because "the
//! playground says Running for minutes" turned out to be a build-profile
//! question, and the numbers are the only way to tell that apart from a hang.
//!
//!   cargo test --features python-runtime --release --test startup_cost -- --nocapture
//!   cargo test --features python-runtime           --test startup_cost -- --nocapture

#![cfg(python_runtime)]

use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::Instant;

use h3xboard_rust::python;

fn assets() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../assets/python")
}

#[test]
fn translating_and_starting_are_both_worth_measuring() {
    let wasm = std::fs::read(assets().join("python.wasm")).expect("python.wasm is an asset");
    let stdlib =
        Arc::new(std::fs::read(assets().join("python314.zip")).expect("the stdlib is an asset"));

    // Paid once per app launch. Eager because lazy translation is unsound with
    // resumable calls (see python::compile), so it cannot be deferred.
    let started = Instant::now();
    let (engine, module) = python::compile(&wasm).expect("the shipped interpreter translates");
    let translate = started.elapsed();

    // Paid per run, and almost all of it is CPython booting rather than the
    // program doing anything.
    let started = Instant::now();
    let outcome = python::run(
        &engine,
        &module,
        Arc::clone(&stdlib),
        "print('hi')\n",
        "",
        Arc::new(AtomicBool::new(false)),
    );
    let first = started.elapsed();

    let started = Instant::now();
    python::run(
        &engine,
        &module,
        Arc::clone(&stdlib),
        "print('hi')\n",
        "",
        Arc::new(AtomicBool::new(false)),
    );
    let second = started.elapsed();

    // A program that raises. CPython only imports traceback/linecache when it
    // actually needs to print one, so this is the first time those come out of
    // the stdlib zip — and it is measured separately because a run that fails
    // has no business being slower than one that works.
    let started = Instant::now();
    let failed = python::run(
        &engine,
        &module,
        Arc::clone(&stdlib),
        "x = 1\ny = x / 0\n",
        "",
        Arc::new(AtomicBool::new(false)),
    );
    let error_first = started.elapsed();

    let started = Instant::now();
    python::run(
        &engine,
        &module,
        stdlib,
        "x = 1\ny = x / 0\n",
        "",
        Arc::new(AtomicBool::new(false)),
    );
    let error_second = started.elapsed();

    println!("translate python.wasm : {translate:?}");
    println!("first run             : {first:?}");
    println!("second run            : {second:?}");
    println!("first failing run     : {error_first:?}");
    println!("second failing run    : {error_second:?}");
    println!("optimised build       : {}", !cfg!(debug_assertions));

    assert_eq!(outcome.stdout, "hi\n");
    assert_eq!(failed.exit_code, 1);
}
