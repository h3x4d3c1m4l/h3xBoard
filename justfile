default: install-flutter get-deps gen-code gen-l10n

set windows-shell := ["pwsh.exe", "-NoProfile", "-c"]

##
# Basic commands
##

install-flutter:
  fvm install -s --skip-pub-get

get-deps:
  fvm flutter pub get

gen-code:
  fvm dart run build_runner clean
  fvm dart run build_runner build

gen-l10n:
  fvm flutter gen-l10n

##
# Watching
##

watch-code:
  fvm dart run build_runner watch

##
# Building
##

[windows]
build-release:
  fvm flutter build windows --release

[linux]
build-release:
  fvm flutter build linux --release

[macos]
build-release:
  fvm flutter build macos --release

build:
  fvm flutter build web

test:
  fvm flutter test

##
# Rust
#
# Only iOS and Android build the Python interpreter into the crate, and they get
# it from the target-gated dependency table in rust/Cargo.toml — cargokit never
# passes --features, so a feature alone could not express "mobile only". The
# `python-runtime` feature exists so a HOST build (these recipes) can compile the
# same code; build.rs folds both routes into one `python_runtime` cfg.
#
# Everything here needs cargo on PATH. Homebrew's rustup keeps its shims in
# /opt/homebrew/opt/rustup/bin and does not add them for you:
#   export PATH="$HOME/.cargo/bin:/opt/homebrew/opt/rustup/bin:$PATH"
##

# Regenerate the Dart <-> Rust bindings after changing anything in rust/src/api.
gen-rust:
  flutter_rust_bridge_codegen generate

lint-rust:
  cargo clippy --manifest-path rust/Cargo.toml --features python-runtime --all-targets -- -D warnings
  cargo fmt --manifest-path rust/Cargo.toml --check

# Runs real Python programs through the real interpreter. Release, because a
# debug-built wasmi turns a 0.4s CPython startup into the best part of a minute.
test-rust:
  cargo test --manifest-path rust/Cargo.toml --features python-runtime --release

# Proves the crate still builds where the interpreter is deliberately absent —
# and, for the targets where it must NOT be, that it really is there. The iOS
# check is the one that matters: a `compile_error!` in lib.rs fails the build if
# the target ever stops pulling the interpreter in, because nothing else would
# notice until a classroom did.
check-rust-targets:
  cargo check --manifest-path rust/Cargo.toml
  cargo check --manifest-path rust/Cargo.toml --target aarch64-apple-ios

##
# Other commands
##

lint:
  fvm flutter analyze

show-outdated:
  fvm flutter pub outdated

upgrade-deps:
  fvm flutter pub upgrade
