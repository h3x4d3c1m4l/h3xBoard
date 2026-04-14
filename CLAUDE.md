# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Flutter is managed via FVM (look at `.fvmrc` for pinned version). Use `fvm flutter` / `fvm dart` instead of bare `flutter` / `dart`. Tasks are run via `just` (Justfile):

```bash
just                    # Full setup: install Flutter, get deps, generate code & l10n
just get-deps           # fvm flutter pub get
just gen-code           # dart run build_runner build --delete-conflicting-outputs
just watch-code         # Watch mode for code generation during development
just gen-l10n           # fvm flutter gen-l10n
just lint               # fvm flutter analyze
just test               # fvm flutter test
just build              # fvm flutter build web (debug)
just build-release      # Platform-specific release build
```

After modifying any `@observable`, `@action`, `@freezed`, or `@RoutePage()` annotated code, re-run `just gen-code` (or keep `just watch-code` running).

## Architecture

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

### Drawing Canvas

`flutter_drawing_board` provides the drawing canvas. A `DrawingController` instance lives on `BoardScreenViewModel` and is passed to components that need to interact with the canvas (tool selection, stroke width/color updates, clear).

### Localization

ARB files live in `lib/l10n/` (`app_en.arb`, `app_nl.arb`). Generated code lands in `lib/l10n/generated/`. Access strings via the `AppLocalizations` extension on `BuildContext`. After editing ARB files, run `just gen-l10n`. The convention for keys is `myWidgetName_short_description`. Localizations can always be accessed by screens using `localizations.myWidgetName_short_description` and by regular widgets using `context.localizations.myWidgetName_short_description` if the following import is added: `import 'package:h3xboard/extensions/build_context_extension.dart';`.

## Key Configuration

- **Line length**: 120 characters (`analysis_options.yaml`); not enforced but more as a guideline
- **Web target with WASM**: CI builds use `--wasm` flag; web is the only target
- **Linting**: 50+ custom rules enabled on top of `flutter_lints`; run `just lint` before pushing
