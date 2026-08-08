//! The bridge surface for running Python.
//!
//! Deliberately small and boring: four calls mirroring the `PythonRuntime`
//! interface Dart already has, so the widget cannot tell which host it got.
//!
//! The signatures never vary by platform. A build without the interpreter — the
//! web bundle, or desktop — still exposes all of them and reports honestly that
//! it cannot run anything, which is the same thing the Dart stub does. That
//! keeps the generated bindings identical everywhere.

use crate::session;

/// What one run of a program produced. Mirrors Dart's `PythonResult`.
pub struct PythonOutcome {
    pub stdout: String,
    pub stderr: String,
    /// 0 when the program finished normally, 130 when Stop was pressed.
    pub exit_code: i32,
    /// Output hit the per-stream cap and was cut short.
    pub truncated: bool,
    pub duration_ms: u64,
}

/// Whether this build can actually run a program. Dart asks before offering Run.
#[flutter_rust_bridge::frb(sync)]
pub fn python_is_supported() -> bool {
    cfg!(python_runtime)
}

/// Hands over `python.wasm` and the standard library zip, once.
///
/// Together they are about 20 MB, so they cross the bridge on first use and are
/// held afterwards; the interpreter is translated once and reused. Calling again
/// is cheap and does nothing.
pub fn python_load(wasm: Vec<u8>, stdlib: Vec<u8>) -> Result<(), String> {
    session::load(wasm, stdlib)
}

/// Runs `code` to completion, feeding `stdin` to `input()`.
///
/// Never fails for a *program* error — a traceback comes back in
/// [`PythonOutcome::stderr`] with a non-zero exit code, because a pupil's
/// mistake is a normal outcome here, not an exception. `Err` means the runtime
/// itself could not start.
pub fn python_run(code: String, stdin: String) -> Result<PythonOutcome, String> {
    session::run(code, stdin)
}

/// Asks a running program to stop.
///
/// Synchronous and lock-free on purpose: it has to be answerable while
/// [`python_run`] is still in flight, so it must not queue behind it.
#[flutter_rust_bridge::frb(sync)]
pub fn python_cancel() {
    session::cancel();
}
