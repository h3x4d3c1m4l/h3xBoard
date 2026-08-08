//! Holds the interpreter between calls, and decides whether there is one at all.
//!
//! Deliberately *not* under `api/`: flutter_rust_bridge walks that whole tree and
//! generates a binding for every public function it finds, including ones inside
//! private modules. Implementation living there ends up on the bridge whether it
//! wants to be or not.
//!
//! Both halves below present the same three functions, so `api::python` never
//! needs a `cfg` of its own.

use crate::api::python::PythonOutcome;

#[cfg(python_runtime)]
mod inner {
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::{Arc, Mutex, OnceLock};

    use crate::api::python::PythonOutcome;
    use crate::python;

    struct Loaded {
        engine: wasmi::Engine,
        module: wasmi::Module,
        stdlib: Arc<Vec<u8>>,
    }

    /// One interpreter, reused across runs.
    ///
    /// The lock also serialises runs, which is what we want: a board full of
    /// playgrounds should not start several CPythons at once. [`cancel`] touches
    /// only an atomic, so Stop is never blocked behind the run it is stopping.
    static LOADED: OnceLock<Mutex<Option<Loaded>>> = OnceLock::new();

    /// Set by [`cancel`] and cleared around every run. Read by the interpreter
    /// between fuel slices — see `python::run`.
    static CANCELLED: AtomicBool = AtomicBool::new(false);

    fn slot() -> &'static Mutex<Option<Loaded>> {
        LOADED.get_or_init(|| Mutex::new(None))
    }

    const POISONED: &str = "The interpreter is in a broken state; restart the app.";

    pub fn load(wasm: Vec<u8>, stdlib: Vec<u8>) -> Result<(), String> {
        let mut guard = slot().lock().map_err(|_| POISONED.to_owned())?;
        if guard.is_some() {
            return Ok(());
        }
        let (engine, module) = python::compile(&wasm).map_err(|error| error.to_string())?;
        *guard = Some(Loaded {
            engine,
            module,
            stdlib: Arc::new(stdlib),
        });
        Ok(())
    }

    pub fn run(code: String, stdin: String) -> Result<PythonOutcome, String> {
        // Clear here rather than in `cancel`, so a Stop that arrived while
        // nothing was running cannot kill the next program before it starts.
        CANCELLED.store(false, Ordering::Relaxed);

        let guard = slot().lock().map_err(|_| POISONED.to_owned())?;
        let loaded = guard
            .as_ref()
            .ok_or("The interpreter has not been loaded yet.")?;

        let outcome = python::run(
            &loaded.engine,
            &loaded.module,
            Arc::clone(&loaded.stdlib),
            &code,
            &stdin,
            &CANCELLED,
        );

        Ok(PythonOutcome {
            stdout: outcome.stdout,
            stderr: outcome.stderr,
            exit_code: outcome.exit_code,
            truncated: outcome.truncated,
            duration_ms: outcome.duration_ms,
        })
    }

    pub fn cancel() {
        CANCELLED.store(true, Ordering::Relaxed);
    }
}

#[cfg(not(python_runtime))]
mod inner {
    use crate::api::python::PythonOutcome;

    const UNAVAILABLE: &str = "This build does not include the Python interpreter.";

    pub fn load(_wasm: Vec<u8>, _stdlib: Vec<u8>) -> Result<(), String> {
        Err(UNAVAILABLE.to_owned())
    }

    pub fn run(_code: String, _stdin: String) -> Result<PythonOutcome, String> {
        Err(UNAVAILABLE.to_owned())
    }

    pub fn cancel() {}
}

pub fn load(wasm: Vec<u8>, stdlib: Vec<u8>) -> Result<(), String> {
    inner::load(wasm, stdlib)
}

pub fn run(code: String, stdin: String) -> Result<PythonOutcome, String> {
    inner::run(code, stdin)
}

pub fn cancel() {
    inner::cancel();
}
