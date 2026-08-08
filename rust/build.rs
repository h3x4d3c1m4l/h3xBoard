//! Works out whether this build has the Python interpreter, and exposes the
//! answer as a single `python_runtime` cfg.
//!
//! There are two ways to get it and they have to agree. A host build opts in
//! with `--features python-runtime` (`just test-rust`). iOS and Android instead
//! pick it up from the target-gated dependency table in Cargo.toml, because
//! cargokit never passes `--features` to cargo — see the note there.
//!
//! Gating the source on the feature alone would compile the interpreter out of
//! exactly the builds that need it, while still paying to compile wasmi: the app
//! would ship and report "unavailable" on iOS and Android. One cfg, derived
//! here, is what keeps the dependency and the code that uses it in step.

fn main() {
    println!("cargo::rerun-if-changed=build.rs");
    println!("cargo::rustc-check-cfg=cfg(python_runtime)");

    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    let via_feature = std::env::var_os("CARGO_FEATURE_PYTHON_RUNTIME").is_some();
    let via_target = matches!(target_os.as_str(), "android" | "ios");

    if via_feature || via_target {
        println!("cargo::rustc-cfg=python_runtime");
    }
}
