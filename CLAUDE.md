# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Flutter is managed via FVM (look at `.fvmrc` for pinned version). Use `fvm flutter` / `fvm dart` instead of bare `flutter` / `dart`. Tasks are run via `just` (Justfile):

```bash
just                    # Full setup: install Flutter, get deps, generate code & l10n
just get-deps           # fvm flutter pub get
just gen-code           # dart run build_runner build
just watch-code         # Watch mode for code generation during development
just gen-l10n           # fvm flutter gen-l10n
just lint               # fvm flutter analyze
just test               # fvm flutter test
just build              # fvm flutter build web (debug)
just build-release      # Platform-specific release build
```

After modifying any `@observable`, `@action`, `@freezed`, or `@RoutePage()` annotated code, re-run `just gen-code` (or keep `just watch-code` running).

## Architecture

### Widget File Placement

Every widget lives under `lib/views/`. The only exception is `lib/board_app.dart` (the app shell) and `lib/external_display/`, which is a second app entry point running in its own isolate and keeps its views next to its protocol.

Placement is **scoped by usage** — a widget lives as close to its only consumer as possible, and only moves up to the shared folder once a second screen needs it:

```text
lib/views/
  base/                     # ScreenBase & friends — closed; nothing goes in or out
  components/               # widgets used by 2+ screens (or by the app shell)
    dialogs/
    flyouts/
    server_chip.dart        # loose files are fine when there is no group to form
  <some>_screen/
    <some>_screen.dart      # the four-file Screen pattern (see below)
    <some>_screen_controller.dart
    <some>_screen_view.dart
    <some>_screen_view_model.dart
    components/             # widgets used only by this screen
      dialogs/
      toolbars/
```

Rules of thumb:

- **One consumer → screen's own `components/`. Two or more (or the app shell) → the shared `lib/views/components/`.** Applies to primitives too: a "generic-looking" widget that only one screen actually uses stays scoped to that screen. Promote it when a second consumer appears, don't pre-promote it.
- Subfolders (`buttons/`, `dialogs/`, `toolbars/`, ...) are created inside a `components/` folder when there is **more than one** of a kind, or when there is a good reason to group.
- Imports point inward-to-outward: a screen-scoped widget may import from `lib/views/components/`, never the reverse.

### Moving files

`build.yaml` scopes each code generator with `generate_for` globs that name **concrete paths** (e.g. `lib/routing/app_router.dart`, `lib/config/env.dart`). Moving or renaming such a file silently disables its generator — the build still "succeeds" and the stale generated output on disk keeps working until someone runs `build_runner clean`. **When you move a file, grep `build.yaml` for its old path and update the glob.**

### Screen Pattern

Every screen is composed of four classes wired together by `ScreenBase<TViewModel, TController, TView>` (in `lib/views/base/`):

- **Screen** – the `StatefulWidget`; creates ViewModel, Controller, View via factory methods
- **ViewModel** (`ScreenViewModelBase` + MobX `Store` mixin) – reactive state with `@readonly`/`@action` MobX annotations; generates a `*.g.dart` file
- **Controller** (`ScreenControllerBase`) – business logic and event handlers; holds a ref to ViewModel and a `BuildContextAccessor`
- **View** (`ScreenViewBase`) – pure UI rendering; reads from ViewModel, calls Controller for actions

Navigation into a screen is done via auto_route (`@RoutePage()` annotation, generated routes in `app_router.dart`). Use `context.replaceRoute()` or similar helpers from `build_context_extension.dart`. Controllers that need to navigate receive a `BuildContextAccessor` and use the `BuildContextAbstractor` mixin.

New screens should follow the existing four-file pattern inside a dedicated folder under `lib/views/`.

### State Management

MobX is used for all reactive state. Observables are declared with `@readonly` (generates a private field + public getter) and mutations are wrapped in `@action` methods. The `Observer` widget from `flutter_mobx` wraps any widget tree that should rebuild on state changes.

### Code Generation

Three generators are active:

- **MobX** – `*.g.dart` for ViewModels
- **Freezed** – `*.freezed.dart` / `*.g.dart` for data classes
- **auto_route** – `app_router.gr.dart` for the route table

Generated files are excluded from linting (`analysis_options.yaml`) and must not be edited manually.

### UI Library

The app uses **fluent_ui** (Windows Fluent Design) for core widgets (`FilledButton`, `ScaffoldPage`, `Flyout`, etc.) and **lucide_icons_flutter** for icons. Do not mix in Material widgets.

### Widget System

Board widgets (clock, stopwatch, traffic light, etc.) follow a registry-driven pattern. The key files are:

```text
lib/models/board_widget.dart                              # Data models
lib/views/board_screen/components/widgets/
  board_widget_descriptor.dart                            # Abstract descriptor + registry
  manipulable_board_widget.dart                          # Positioning/scaling/rotation wrapper
  widget_selection_overlay.dart                          # Selection UI
  clock_widget.dart, stopwatch_widget.dart, ...          # Concrete widgets
```

**Data model** (`board_widget.dart`): Two freezed types:

- `BoardWidgetConfig` – sealed union; one subtype per widget (e.g. `ClockConfig`, `StopwatchConfig`)
- `BoardWidget` – runtime instance with `id`, `config`, `x`, `y`, `rotation`, `scale`; canvas space is 1920×1080

**Descriptor** (`board_widget_descriptor.dart`): Abstract `BoardWidgetDescriptor` exposes `icon`, `label()`, `naturalSize`, `defaultConfig`, `buildWidget(config)`, and `settingsMenuItems(...)`. Concrete descriptors are singletons registered in `widgetRegistry` (a `const` map keyed by config type). Use `descriptorFor(config)` anywhere type-dispatch is needed — no switch statements in rendering code.

**Rendering**: `ManipulableBoardWidget` wraps each widget with `Positioned` (center-based), `Transform.rotate`, and `FittedBox` applied in that order. `Board` iterates `boardWidgets` and calls `descriptorFor(bw.config).buildWidget(bw.config)` — fully generic.

**Adding a new widget type** requires exactly three changes:

1. Add a new `@freezed` subtype to `BoardWidgetConfig` in `board_widget.dart` → run `just gen-code`
2. Create the widget Flutter class in `lib/views/board_screen/components/widgets/`; declare a static `Size naturalSize`
3. Implement `BoardWidgetDescriptor` and register it in `widgetRegistry` in `board_widget_descriptor.dart`

No other files need changes. Settings menu items (Fluent UI flyout) are provided by the descriptor's `settingsMenuItems()`.

**Layers**: Widget list order = render order (last = topmost). Layer operations (`moveToTop`, `moveUp`, etc.) reorder the list.

### Drawing Canvas

`flutter_drawing_board` provides the drawing canvas. A `DrawingController` instance lives on `BoardScreenViewModel` and is passed to components that need to interact with the canvas (tool selection, stroke width/color updates, clear).

### Localization

ARB files live in `lib/l10n/` (`app_en.arb`, `app_nl.arb`). Generated code lands in `lib/l10n/generated/`. Access strings via the `AppLocalizations` extension on `BuildContext`. After editing ARB files, run `just gen-l10n`. The convention for keys is `myWidgetName_short_description`. Localizations can always be accessed by screens using `localizations.myWidgetName_short_description` and by regular widgets using `context.localizations.myWidgetName_short_description` if the following import is added: `import 'package:h3xboard/extensions/build_context_extension.dart';`.

## Code Style

### Class body padding

Every class body must have a blank line after the opening `{` and a blank line before the closing `}`:

```dart
class MyClass {

  final String myVar;

  void myMethod() {
  }

}
```

This applies to all classes: widgets, state classes, descriptors, freezed classes, abstract classes, etc.

## Key Configuration

- **Line length**: 120 characters (`analysis_options.yaml`); not enforced but more as a guideline
- **Linting**: 50+ custom rules enabled on top of `flutter_lints`; run `just lint` before pushing
