//! Everything Dart can call. `flutter_rust_bridge_codegen` reads this tree and
//! nothing else, so a function is only reachable from Flutter once it appears
//! here — see flutter_rust_bridge.yaml and `just gen-rust`.

pub mod python;

/// Runs once, the first time Dart initialises the bridge.
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Routes Rust panics and logging somewhere visible from Dart rather than
    // letting them vanish into the platform log.
    flutter_rust_bridge::setup_default_user_utils();
}
