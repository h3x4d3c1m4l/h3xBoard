pub mod api;

/// Holds the loaded interpreter between bridge calls. Outside `api/` on purpose
/// — see the note at the top of that file.
mod session;

/// The CPython host. Only compiled where the interpreter is — see build.rs for
/// what decides that. Public so `tests/python_runs.rs` can drive it directly
/// with real programs, which is the only way to keep it honest against the
/// browser shim it mirrors.
#[cfg(python_runtime)]
pub mod python;

// The mobile builds are the whole point, and nothing else would notice if they
// silently lost the interpreter: the app would build, ship, and report "running
// Python is not available on this platform" to a classroom. Fail the build
// instead.
#[cfg(all(any(target_os = "ios", target_os = "android"), not(python_runtime)))]
compile_error!(
    "iOS and Android must build with the Python interpreter. \
     build.rs derives `python_runtime` from the target, and Cargo.toml pulls wasmi in \
     through a target-gated dependency table — one of the two has drifted."
);

mod frb_generated;
