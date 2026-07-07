# h3xBoard

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Patched dependencies (temporary)

### `external_display` (vendored fork in `third_party/external_display`)

We ship a local, patched copy of [`external_display`](https://pub.dev/packages/external_display)
`0.4.3`, wired in via a `path` `dependency_overrides` entry in `pubspec.yaml`.
The upstream package has no newer release with these fixes.

**Why the fork exists:**

1. **iOS external window sized to the wrong resolution.** On iOS the plugin
   picked `UIScreen.availableModes.last`, which on many displays (e.g. a 4K
   screen that lists a legacy `720x480` mode last) produced a tiny external
   window in the top-left corner. The fork sizes the window from the panel's
   **native resolution** (`UIScreen.nativeBounds`) instead — some panels (the
   iOS Simulator's external display included) don't even list their native
   resolution among `availableModes`.
2. **No way to choose the resolution from Dart.** The fork adds a `getModes()`
   method and `width`/`height` parameters to `connect()`, which power the
   external-display resolution picker in **Settings**.

All changes live in
`third_party/external_display/ios/Classes/ExternalDisplayPlugin.swift`,
`third_party/external_display/lib/external_display.dart`, and a graceful no-op
`getModes` on Android.

**Remove this fork when** upstream ships a release that fixes the mode selection
and exposes resolution control (or we migrate to a better-maintained plugin):
delete `third_party/external_display`, drop the `dependency_overrides` block in
`pubspec.yaml`, bump the `external_display` dependency, and run `just get-deps`.
