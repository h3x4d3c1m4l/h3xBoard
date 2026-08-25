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
just gen-emoji          # Build assets/emoji/ (gitignored; no-ops when current)
just gen-emoji-force    # Rebuild it after bumping the pinned Emoji/Noto/CLDR versions
just lint               # fvm flutter analyze
just test               # fvm flutter test
just build              # fvm flutter build web (debug)
just build-release      # Platform-specific release build
```

After modifying any `@observable`, `@action`, `@freezed`, or `@RoutePage()` annotated code, re-run `just gen-code` (or keep `just watch-code` running).

**The `sdk: ^3.12.0` constraint in pubspec.yaml is load-bearing — do not raise it to match the Flutter pin.** Dart 3.13 dropped support for `final` on constructor parameters, which freezed 3.2.5 still emits, so generated code stops compiling (`Error: Can't have modifier 'final' here`). The lower bound of `sdk:` is this package's *language version*, so declaring 3.12 keeps that syntax legal while everything still runs on the Flutter 3.47 / Dart 3.13 SDK. Nothing needs patching.

The trap if it ever does get raised: `flutter analyze` accepts the offending code, so lint stays green while every build and test fails. Raising it needs freezed 4.x, which is itself blocked — it wants `analyzer ^13` while `mobx_codegen` (latest 2.7.7) caps `analyzer <13`.

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

### Workarounds get their own widget

Where a widget *lives* is the section above; this is about what earns being one. When something needs a trick to work — a framework quirk to route around, a clip that has to be undone, a measurement that drives a rebuild — **that trick gets its own widget, and everything else uses it as a plain drop-in.** A workaround spread across its call sites is a contract each of them can break silently, and none of them can check.

`lib/views/components/dialogs/dialog_scroll_area.dart` is the worked example. It carries two unrelated tricks and leaks neither:

- **A vertical viewport clips to its own box**, which shaves the left and right border off every control inside it — a `ContinuousRectangleBorder` strokes half its width *outside* the path it draws. The first fix had each caller shave a few pixels off its own padding and hand them back as inner padding: three call sites doing arithmetic that all had to agree. It is now `clipBehavior: Clip.none` plus a `RelaxedHorizontalClipper` that keeps the vertical bounds and relaxes the sideways ones. Layout is untouched, so callers pass nothing and can't get it wrong.
- **The scroll end gaps are spent on the scrollable's own extent**, and a `SingleChildScrollView` sizes itself to that extent — so applying them unconditionally grows every dialog that *doesn't* scroll. The widget watches `ScrollMetricsNotification` and measures the extent minus the gaps it has already added, so the answer can't feed back on itself.

Two things that come with the deal:

- **Name the trick.** `RelaxedHorizontalClipper` says what it does; a bare inlined `CustomClipper` would not.
- **Write down the framework behaviour you are leaning on**, because that is what makes a workaround reviewable instead of load-bearing folklore. Here: `RenderStack` flags overflow only from *positioned* children, which is why a relaxed clip survives `ScrollEdgeHint`'s `Stack`.

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

Four generators are active:

- **MobX** – `*.g.dart` for ViewModels
- **Freezed** – `*.freezed.dart` / `*.g.dart` for data classes
- **auto_route** – `app_router.gr.dart` for the route table
- **theme_tailor** – `app_theme.tailor.dart` for the theme extension (`copyWith`/`lerp`/equality)

Generated files are excluded from linting (`analysis_options.yaml`) and must not be edited manually.

### UI Library

The app uses **fluent_ui** (Windows Fluent Design) for core widgets (`FilledButton`, `ScaffoldPage`, `Flyout`, etc.) and **lucide_icons_flutter** for icons. Do not mix in Material widgets.

### Theming

`lib/theme/theme.dart` builds the `FluentThemeData`; `lib/theme/shape_metrics.dart` holds the radii/padding constants; `lib/theme/app_theme.dart` is the app's own `ThemeExtension` (theme_tailor), read anywhere via `context.appTheme`.

Fluent can only style a control by its **widget type** — one `defaultButtonStyle` for every `Button` in the app. Our buttons play far more roles than that, so `AppTheme` names them (`buttons.neutral`, `buttons.tab`, `buttons.exit`, `surfaces.toolbar`, `colors.selection`, …) and widgets ask for the style they *mean*. **Write a style there, not inline in a widget.** The fluent slots in `theme.dart` are wired to the same roles, so a role is defined once.

Two consequences worth knowing:

- Fluent builds several *controls* out of a plain `Button` — `ComboBox`'s closed state, `DropDownButton`, `SplitButton`, `ColorPicker`'s internals — so anything set on `defaultButtonStyle` reaches them too. Wrap those in `ButtonTheme.merge(data: plainControlButtonTheme(context), …)` to opt out (see `custom_color_button.dart`). Dropdowns instead go through `ContinuousComboBox`, which hands them `buttons.comboBox` — the same outline at `kShortControlCornerRadius`, because fluent pins a combo box to a fixed 32px height that the full control radius would swallow.
- `ToggleButton` gets only its *checked* style from fluent (and hardcodes rounded corners there), while the unchecked state falls through to `defaultButtonStyle`. Both `toggleButtonTheme` slots are therefore set explicitly.

`context.appTheme` falls back to `AppTheme.standard` when the ambient theme carries no extension (widget tests that build their own `FluentThemeData`), so it never null-checks. Alt+D → "fluent_ui widget gallery" renders every button type over a switchable backdrop for eyeballing theme changes.

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

**The descriptor's `emoji` needs `just gen-emoji` after step 3.** It is what the add-widget menu draws, and it is served from a preloaded pack, not from the emoji's individual asset. The generator *scans the descriptor files* for `String get emoji` and stamps the resulting key list into `index.json`, so a new widget invalidates the output and a plain `just gen-emoji` rebuilds `ui.pack` — no `--force`, no list to keep in sync by hand. Forget to run it and `test/emoji_pack_test.dart` fails by name; the menu still draws in the meantime, falling back to the individual asset. Pick an emoji the Noto set covers — the generator hard-fails and names it if not.

**Two ways in, both from the toolbar's last group** ([tool_toolbar.dart](lib/views/board_screen/components/toolbars/tool_toolbar.dart)): `AddWidgetButton` opens the emoji menu (every catalog widget, alphabetical by localized label, one tap to place), and its last row opens `WidgetCatalogDialog` — the dialog is what offers live previews and search, which a menu cannot. A descriptor opts out of both with `showInCatalog => false`.

**`BoardSettingsButton` is deliberately *not* in the toolbar** — it restyles the board, not what a tool does. It hangs off the bar's trailing end via `BalancedTrailing`, so it rides the bar's hide animation while staying out of its groups. That widget exists because `BoardScaffold` centres whatever it is handed: a plain `Row(children: [bar, button])` would slide the bar off centre by half the button's width, silently and with a perfectly valid layout. An invisible copy of the button on the leading side restores the balance whatever it measures — the same counterweight trick as `BalancedSide` in the top bar, in a `Flex` rather than a `Stack`. `test/balanced_trailing_test.dart` is what holds the centring; the button is built twice, so it must not carry a `GlobalKey`.

**Layers**: Widget list order = render order (last = topmost). Layer operations (`moveToTop`, `moveUp`, etc.) reorder the list.

### Emoji

The emoji widget draws from **bundled Noto Emoji vector artwork**, not from a color font. This is not a preference: Flutter's Impeller renderer rasterizes neither CBDT/CBLC bitmap tables nor COLRv1 vector tables, so a bundled emoji font renders as *nothing at all* on iOS/Android/macOS. Compiled `vector_graphics` (`.vec`) go through the ordinary canvas path, so an emoji looks the same in the editor, the external-display isolate and the web viewer — and stays sharp at any scale.

```text
tool/generate_emoji_assets.dart     # `just gen-emoji` — the whole pipeline
assets/emoji/vec/<key>.vec          # 3564 compiled artworks (~16 MB)
assets/emoji/packs/<group>.pack     # the same base artwork, one file per category
assets/emoji/packs/<group>.<tone>.pack   # that category's skin-tone variants
assets/emoji/packs/ui.pack          # the app's own emoji (descriptor `emoji`), ~30 KB
assets/emoji/index.json             # groups, Unicode order, skin-tone variants, ui stamp
assets/emoji/labels_<locale>.json   # CLDR names + search keywords per locale
lib/services/emoji/emoji_repository.dart   # asset keys, lazy catalog, search
lib/services/emoji/emoji_pack_store.dart   # pack parsing + BytesLoader
lib/services/emoji/ui_emoji_pack.dart      # ui.pack, preloaded at startup
```

Every asset directory is listed separately in pubspec.yaml — **Flutter does not recurse into subdirectories**, so a new folder under `assets/emoji/` is silently absent until it is declared.

**Three ways in to the same artwork, because the board, the picker and the app's own chrome want different things.** The board draws a handful of emoji, so it loads each `.vec` individually — on web that is one small fetch per emoji actually on the page, which is what keeps the anonymous viewer cheap. The picker shows hundreds at once, where that same design cost ~113 requests to open and ~1900 to browse the catalog. It reads one pack per category instead: 1 request to open, 9 to browse everything.

The third is `UiEmojiPack`, for emoji the app itself draws — today the descriptor `emoji` in the add-widget menu. It differs from the picker's packs on both counts: it is tiny (~30 KB for ~19 entries, against megabytes per category) and it is needed the moment a menu opens rather than as something scrolls into view. So it is **loaded once at startup** — in `InitializationScreenController._bootstrap`, riding along with the fonts step — and then answers synchronously. `loaderFor` returning null is a normal, handled state (pack not arrived yet, or an emoji added since the last `just gen-emoji`); `EmojiImage` falls back to the emoji's own asset, so the menu always draws.

Three things that are easy to get wrong here:

- **Skin tones get their own packs** (`peopleBody.dark.pack`), fetched only while that tone is selected. Folding them into the base pack took People & Body from ~1.5 MB to ~9 MB that most users never display; leaving them out entirely was worse, because anyone with a tone selected then pulled hundreds of individual files — the exact problem packs exist to solve. Only categories with toned emoji have toned packs, so `EmojiGroup.hasSkinTones` decides whether to ask (otherwise every category costs a 404).
- **Pack loading is driven by scroll geometry, not by tile builds.** Slivers build a probe child per category to establish geometry, so loading on first build pulls all nine packs the moment the picker opens. `EmojiPackStore.isLoaded` is therefore a pure query and `request` is explicit, called from `_requestVisiblePacks`.
- **The pack format is a contract between the generator and the runtime**, and a wrong offset draws the wrong emoji rather than failing. `test/emoji_pack_test.dart` compares every packed entry byte-for-byte against its individual asset.

Everything under `assets/emoji/` is generated and **gitignored**, like every other generated artifact in this repo — ~3.5k files / ~16 MB is rebuilt rather than committed. `just gen-emoji` therefore runs as part of the default setup; it stamps the pinned versions into `index.json` and no-ops when the output already matches, so only a fresh clone or a version bump pays for it. It prints a coverage report and **names** any emoji it had to skip, so a gap can't hide as a silent success.

To adopt a newer Emoji release, bump `_notoTag` / `_cldrTag` / `_expectedEmojiVersion` at the top of the script and run `just gen-emoji-force`. `emoji-test.txt` is the one source that can't be pinned by URL — Unicode publishes no per-version directory for 17.0 — so the generator hard-fails if `latest/` ever serves a version other than `_expectedEmojiVersion`, rather than quietly building against a spec the artwork doesn't cover.

Two things to know:

- **Asset keys are derived, not stored.** A board stores the literal emoji characters; `emojiAssetKey` in the repository re-derives the file name from them (variation selectors dropped, code points padded to four hex digits — Noto's own convention). The generator and the runtime must produce byte-identical keys; `test/emoji_catalog_test.dart` is what holds that contract, and it checks every bundled emoji resolves.
- **Country flags come from a second source.** Noto keeps them in `third_party/region-flags/waved-svg`, not in `svg/` — miss that and 262 flags silently vanish.

Adding a locale means adding it to `_locales` in the generator and re-running; unlisted locales fall back to English names so the picker still works everywhere.

### Drawing Canvas

`flutter_drawing_board` provides the drawing canvas. A `DrawingController` instance lives on `BoardScreenViewModel` and is passed to components that need to interact with the canvas (tool selection, stroke width/color updates, clear).

### Live Share (external display + web viewer)

One delta protocol mirrors the active board to two kinds of second screen: the physically attached external display (USB-C/AirPlay, `lib/external_display/`) and anonymous web viewers watching by code through the backend. The message vocabulary is `LiveShareMessage` (`lib/models/live_share/live_share_message.dart`, freezed union, wire-discriminated on `type`): a full `snapshot` on connect/board-switch/resync, small deltas (`boardProps`, `widgetUpserted`, `strokeProgress`, …) for everything else, with a per-session `seq` for gap detection on lossy transports. **The server relays envelopes verbatim and reads only `type`, `seq` and snapshot `fileIds`** — renaming a JSON key here is a protocol change that must be mirrored in h3xBoardServer (see its `docs/live-sharing.md`).

```text
BoardScreenController ─ LiveBoardPublisher (diff engine: MobX autorun + drawing notifiers)
                              │ LiveShareMessage
                              ▼
                        LiveShareHub (GetIt singleton)
                         ├ ExternalDisplaySink → plugin bus → external isolate ┐
                         └ ServerShareSink → sharing.v1.publish (batched)      ├→ LiveBoardReceiver → LiveBoardView
                                                     viewer ← /ws/v1/view/{code} (LiveViewClient) ┘
```

Key pieces: send side in `lib/services/live_share/` (`LiveBoardPublisher` diffs state — mutation points are *not* instrumented, because undo/redo bypasses the controller); receive side shared by both mirrors (`LiveBoardReceiver` applies messages, `LiveBoardView` renders with the fade-through-black transition); `LiveShareSessionService` owns the presenter session (code, viewer count, heartbeat, reconnect-resume); the viewer is `lib/views/viewer_screen/` (anonymous route `/view` + `/view/:code`, exempted in `auth_guard.dart`). Asset bytes (image widgets, backgrounds) resolve through `BoardAssetResolver` via the `BoardAssets` scope: authed file service in the editor, bytes-over-the-bus in the external isolate, the anonymous `/api/v1/view/{code}/files/{fileId}` endpoint for web viewers. Strokes crossing JSON need the int→double normalization in `lib/services/drawing_serialization.dart` — always rehydrate through `restoreDrawingContents`.

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
