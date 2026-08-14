default: install-flutter get-deps gen-code gen-l10n gen-emoji

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

# Builds assets/emoji/ from Noto Emoji + Unicode CLDR. The output is gitignored,
# so a fresh clone needs this once; it no-ops when already current, which is why
# it can sit in the default setup. Bump the pinned tags in the script and run
# `just gen-emoji-force` to adopt a newer Emoji release.
gen-emoji:
  fvm dart run tool/generate_emoji_assets.dart

gen-emoji-force:
  fvm dart run tool/generate_emoji_assets.dart --force

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
# Other commands
##

lint:
  fvm flutter analyze

show-outdated:
  fvm flutter pub outdated

upgrade-deps:
  fvm flutter pub upgrade
