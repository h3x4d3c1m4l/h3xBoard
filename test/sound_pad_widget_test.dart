import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show DebugPrintCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/sound_pad_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The sound pad's config contract and its two states that need no audio device
/// to test: no sound chosen, and no way to fetch the bytes.
///
/// Playback itself is deliberately not covered here — it needs a real output
/// device, which a headless test runner does not have. What *is* covered is
/// everything that decides whether playback is even attempted, and the
/// classification that keeps a tap out of undo history.
void main() {
  Widget wrap(Widget child) => FluentApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScaffoldPage(content: Center(child: SizedBox(width: 260, height: 300, child: child))),
      );

  group('runtime state', () {
    test('firing a pad is runtime-only, so it mirrors without entering undo history', () {
      const before = SoundPadConfig(fileId: 'f1', label: 'Applause');
      final after = before.copyWith(triggerSeed: before.triggerSeed + 1);

      expect(isWidgetRuntimeOnlyChange(before, after), isTrue);
    });

    test('stopping a pad is runtime-only too', () {
      const before = SoundPadConfig(fileId: 'f1', stopSeed: 3);
      final after = before.copyWith(stopSeed: 4);

      expect(isWidgetRuntimeOnlyChange(before, after), isTrue);
    });

    test('every tap differs from the config it came from, so no empty undo entry', () {
      // isWidgetRuntimeOnlyChange requires old != new. A trigger that produced an
      // identical config would fall through to the undoable branch and push an
      // empty history entry on every tap.
      var config = const SoundPadConfig(fileId: 'f1');
      for (var i = 0; i < 50; i++) {
        final fired = config.copyWith(triggerSeed: config.triggerSeed + 1);
        expect(fired, isNot(config), reason: 'tap $i produced an identical config');
        config = fired;
      }
    });

    test('choosing a different sound is a real edit, not runtime state', () {
      const before = SoundPadConfig(fileId: 'f1', label: 'Applause');
      final after = before.copyWith(fileId: 'f2', label: 'Drum roll');

      expect(isWidgetRuntimeOnlyChange(before, after), isFalse);
    });

    test('renaming a pad is a real edit', () {
      const before = SoundPadConfig(fileId: 'f1', label: 'Applause');
      final after = before.copyWith(label: 'Clapping');

      expect(isWidgetRuntimeOnlyChange(before, after), isFalse);
    });

    test('clearing runtime state leaves the pad pointing at the same sound', () {
      const config = SoundPadConfig(fileId: 'f1', label: 'Applause', emoji: '👏', triggerSeed: 9, stopSeed: 4);
      final cleared = clearWidgetRuntimeState(config) as SoundPadConfig;

      expect(cleared.triggerSeed, 0);
      expect(cleared.stopSeed, 0);
      expect(cleared.fileId, 'f1');
      expect(cleared.label, 'Applause');
      expect(cleared.emoji, '👏');
    });
  });

  group('descriptor', () {
    test('is registered, so descriptorFor can dispatch to it', () {
      expect(descriptorFor(const SoundPadConfig()), isA<SoundPadWidgetDescriptor>());
      expect(widgetRegistry[SoundPadConfig], SoundPadWidgetDescriptor.instance);
    });

    test('appears in the add-widget catalog', () {
      expect(SoundPadWidgetDescriptor.instance.showInCatalog, isTrue);
    });

    test('keeps the standard header bar, so the body means only "fire"', () {
      // A pad draggable by its face would fire every time it was moved.
      const descriptor = SoundPadWidgetDescriptor.instance;
      expect(descriptor.hasHeaderBar, isTrue);
      expect(descriptor.isDraggableInSelectMode, isFalse);
    });
  });

  group('rendering', () {
    testWidgets('a pad with no sound yet renders its placeholder instead of a name', (tester) async {
      await tester.pumpWidget(wrap(SoundPadWidget(
        fileId: '',
        label: '',
        emoji: '🔊',
        volume: 1,
        triggerSeed: 0,
        stopSeed: 0,
        onTrigger: () {},
        onStop: () {},
      )));

      expect(find.text('No sound'), findsOneWidget);
    });

    testWidgets('a pad shows its label once it has one', (tester) async {
      await tester.pumpWidget(wrap(SoundPadWidget(
        fileId: 'f1',
        label: 'Applause',
        emoji: '👏',
        volume: 1,
        triggerSeed: 0,
        stopSeed: 0,
        onTrigger: () {},
        onStop: () {},
      )));

      expect(find.text('Applause'), findsOneWidget);
      expect(find.text('No sound'), findsNothing);
    });

    testWidgets('an idle pad shows no stop badge', (tester) async {
      await tester.pumpWidget(wrap(SoundPadWidget(
        fileId: 'f1',
        label: 'Applause',
        emoji: '👏',
        volume: 1,
        triggerSeed: 0,
        stopSeed: 0,
        onTrigger: () {},
        onStop: () {},
      )));

      // The badge exists only while voices are live, so a pad that has never
      // been tapped must not offer to stop anything. Matched on the icon the
      // badge actually draws: a FluentIcons glyph would find nothing whether the
      // badge was there or not.
      expect(find.byIcon(LucideIcons.square), findsNothing);
    });

    testWidgets('renders without a BoardAssets resolver, as it must on a mirror', (tester) async {
      // The external-display isolate has no app services, so maybeResolverOf
      // returns null there. Building must not throw, and tapping must not either.
      await tester.pumpWidget(wrap(SoundPadWidget(
        fileId: 'f1',
        label: 'Applause',
        emoji: '👏',
        volume: 1,
        triggerSeed: 0,
        stopSeed: 0,
        onTrigger: () {},
        onStop: () {},
      )));

      await tester.tap(find.byType(SoundPadWidget));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('pointing a pad at a sound', () {
    // The service is never dereferenced: resolving a length goes through
    // BoardAudioEngine, which gives up before reading any bytes when there is no
    // audio device. That give-up is logged with a stack trace, which carries no
    // signal here and would drown the rest of the suite.
    H3xBoardFileService files() => H3xBoardFileService.create('http://localhost', CookieStore());

    late DebugPrintCallback realDebugPrint;
    setUp(() {
      realDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
    });
    tearDown(() => debugPrint = realDebugPrint);

    Future<SoundPadConfig> pointAt(String fileId, {SoundPadConfig? base, String? fileName}) =>
        SoundPadWidgetDescriptor.configForFile(
          files(),
          fileId,
          base: base ?? const SoundPadConfig(),
          fileName: fileName,
        );

    test('takes its label from the file name, extension dropped', () async {
      final config = await pointAt('f1', fileName: 'applause.mp3');

      expect(config.label, 'applause');
    });

    test('replacing the sound re-labels it, rather than keeping the old name', () async {
      // A pad cannot be renamed, so its label only ever describes the sound it
      // points at. Keeping the old one captioned the new sound wrongly.
      const loaded = SoundPadConfig(fileId: 'f1', label: 'applause');

      final config = await pointAt('f2', base: loaded, fileName: 'airhorn.mp3');

      expect(config.label, 'airhorn');
      expect(config.fileId, 'f2');
    });

    test('keeps the emoji and volume, which describe the pad rather than the file', () async {
      const loaded = SoundPadConfig(fileId: 'f1', label: 'applause', emoji: '\u{1F44F}', volume: 0.5);

      final config = await pointAt('f2', base: loaded, fileName: 'airhorn.mp3');

      expect(config.emoji, '\u{1F44F}');
      expect(config.volume, 0.5);
    });
  });

  group('the pad body is only ever a trigger', () {
    testWidgets('has no editor, so a double tap fires the sound instead of opening a picker', (tester) async {
      // A soundboard pad is a thing you hit repeatedly. Opening the file picker
      // on the second hit would make a drum roll unplayable. The board wires its
      // double tap to editAction, so returning null is what unwires it.
      late BuildContext ctx;
      await tester.pumpWidget(wrap(Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })));

      expect(SoundPadWidgetDescriptor.instance.editAction(ctx, const SoundPadConfig(), (_) {}), isNull);
    });

    testWidgets('offers a sound and an emoji, and nothing that renames it', (tester) async {
      // The label is derived from the file, so a rename would be undone by the
      // next replacement.
      late BuildContext ctx;
      await tester.pumpWidget(wrap(Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      })));

      final items = SoundPadWidgetDescriptor.instance.settingsMenuItems(ctx, const SoundPadConfig(), (_) {});
      final labels = items.whereType<MenuFlyoutItem>().map((i) => (i.text as Text).data!).toList();

      expect(labels, ['Choose sound…', 'Change emoji…']);
    });
  });

}
