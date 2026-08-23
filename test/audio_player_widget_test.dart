import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show DebugPrintCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/board_screen/components/widgets/audio_player_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/components/board_audio_scope.dart';

/// The audio player's position maths and config contract.
///
/// The rule worth protecting here is that a receiver **never** reconstructs the
/// position from `now - startedAtEpochMs`. Two devices' clock offsets can differ
/// by seconds. On a stopwatch that drift is invisible; on a track it means
/// starting somewhere else entirely — or, past the end, not playing at all.
void main() {
  Widget wrap(Widget child, {BoardAudioPolicy policy = const SilentBoardAudioPolicy()}) => FluentApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScaffoldPage(
          content: Center(
            child: SizedBox(
              width: 560,
              height: 220,
              child: BoardAudioScope(policy: policy, child: child),
            ),
          ),
        ),
      );

  AudioPlayerWidget player({
    String fileId = 'track-1',
    String title = 'Intro music',
    int positionMs = 0,
    int? startedAtEpochMs,
    int? durationMs = 180000,
    // Defaults to a format that is loaded whole, so these tests exercise the
    // ordinary path unless one of them deliberately asks for streaming.
    String? contentType = 'audio/wav',
    bool loop = false,
    void Function(int, int?)? onPlaybackChanged,
  }) =>
      AudioPlayerWidget(
        fileId: fileId,
        title: title,
        volume: 1,
        loop: loop,
        positionMs: positionMs,
        startedAtEpochMs: startedAtEpochMs,
        durationMs: durationMs,
        contentType: contentType,
        onPlaybackChanged: onPlaybackChanged ?? (_, _) {},
        onLoopChanged: (_) {},
        onVolumeChanged: (_) {},
      );

  group('runtime state', () {
    test('playing is runtime-only, so it mirrors without entering undo history', () {
      const before = AudioPlayerConfig(fileId: 'track-1');
      final after = before.copyWith(startedAtEpochMs: 1000, positionMs: 0);

      expect(isWidgetRuntimeOnlyChange(before, after), isTrue);
    });

    test('scrubbing is runtime-only too', () {
      const before = AudioPlayerConfig(fileId: 'track-1', positionMs: 1000, startedAtEpochMs: 500);
      final after = before.copyWith(positionMs: 90000);

      expect(isWidgetRuntimeOnlyChange(before, after), isTrue);
    });

    test('toggling loop is a real edit — it survives a reload, so it must be undoable', () {
      const before = AudioPlayerConfig(fileId: 'track-1');
      final after = before.copyWith(loop: true);

      expect(isWidgetRuntimeOnlyChange(before, after), isFalse);
    });

    test('choosing a different track is a real edit', () {
      const before = AudioPlayerConfig(fileId: 'track-1', title: 'Intro');
      final after = before.copyWith(fileId: 'track-2', title: 'Outro');

      expect(isWidgetRuntimeOnlyChange(before, after), isFalse);
    });

    test('clearing runtime state rewinds without forgetting the track', () {
      const config = AudioPlayerConfig(
        fileId: 'track-1',
        title: 'Intro',
        loop: true,
        positionMs: 90000,
        startedAtEpochMs: 1234,
        durationMs: 180000,
      );
      final cleared = clearWidgetRuntimeState(config) as AudioPlayerConfig;

      expect(cleared.positionMs, 0);
      expect(cleared.startedAtEpochMs, isNull);
      expect(cleared.fileId, 'track-1');
      expect(cleared.title, 'Intro');
      expect(cleared.loop, isTrue, reason: 'loop is a setting, not playback state');
      expect(cleared.durationMs, 180000);
    });
  });

  group('descriptor', () {
    test('is registered, so descriptorFor can dispatch to it', () {
      expect(descriptorFor(const AudioPlayerConfig()), isA<AudioPlayerWidgetDescriptor>());
      expect(widgetRegistry[AudioPlayerConfig], AudioPlayerWidgetDescriptor.instance);
    });

    test('appears in the add-widget catalog', () {
      expect(AudioPlayerWidgetDescriptor.instance.showInCatalog, isTrue);
    });
  });

  group('pointing a player at a file', () {
    // The service is never dereferenced here. Resolving a length goes through
    // BoardAudioEngine, which gives up before reading any bytes when there is no
    // audio device — and a test runner has none. Constructing one is still
    // cheap, and it opens no connection until something calls it.
    H3xBoardFileService files() => H3xBoardFileService.create('http://localhost', CookieStore());

    // That give-up is logged with a stack trace, once per lookup. Swallowing it
    // is the engine behaving as documented, so the trace carries no signal here
    // and six copies of it would drown the rest of the suite.
    late DebugPrintCallback realDebugPrint;
    setUp(() {
      realDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
    });
    tearDown(() => debugPrint = realDebugPrint);

    Future<AudioPlayerConfig> pointAt(String fileId, {AudioPlayerConfig? base, String? fileName}) =>
        AudioPlayerWidgetDescriptor.configForFile(
          files(),
          fileId,
          base: base ?? const AudioPlayerConfig(),
          fileName: fileName,
        );

    test('takes its title from the file name, extension dropped', () async {
      final config = await pointAt('f1', fileName: 'closing-theme.mp3');

      expect(config.title, 'closing-theme');
      expect(config.fileId, 'f1');
    });

    test('replacing the track re-titles it, rather than keeping the old name', () async {
      // The regression. A player has no rename, so its title is only ever
      // derived from the file. Preserving a non-empty title therefore meant every
      // replacement after the first showed the *first* track's name.
      const loaded = AudioPlayerConfig(fileId: 'f1', title: 'intro', durationMs: 1000);

      final config = await pointAt('f2', base: loaded, fileName: 'closing-theme.mp3');

      expect(config.title, 'closing-theme');
      expect(config.fileId, 'f2');
    });

    test('a name with no extension is used whole', () async {
      final config = await pointAt('f1', fileName: 'applause');

      expect(config.title, 'applause');
    });

    test('a dotfile keeps its name rather than becoming empty', () async {
      final config = await pointAt('f1', fileName: '.hidden');

      expect(config.title, '.hidden');
    });

    test('no name at all leaves the title empty, which renders as "Untitled"', () async {
      // Falling back to the previous title would be worse: it would label the
      // new track with the old one's name.
      const loaded = AudioPlayerConfig(fileId: 'f1', title: 'intro');

      final config = await pointAt('f2', base: loaded);

      expect(config.title, isEmpty);
    });

    test('a replacement starts at the beginning, whatever the old track was doing', () async {
      const playing = AudioPlayerConfig(
        fileId: 'f1',
        title: 'intro',
        positionMs: 45000,
        startedAtEpochMs: 1700000000000,
      );

      final config = await pointAt('f2', base: playing, fileName: 'closing-theme.mp3');

      expect(config.positionMs, 0);
      expect(config.startedAtEpochMs, isNull);
    });
  });

  group('position', () {
    final t0 = DateTime.utc(2026, 1, 1, 12);

    test('a paused player sits exactly where it was left', () {
      expect(
        audioPlayerPosition(baseMs: 65000, startedHere: null, now: t0, durationMs: 180000),
        const Duration(milliseconds: 65000),
      );
    });

    test('a playing player counts forward from where it started, on this clock', () {
      expect(
        audioPlayerPosition(
          baseMs: 65000,
          startedHere: t0,
          now: t0.add(const Duration(seconds: 3)),
          durationMs: 180000,
        ),
        const Duration(milliseconds: 68000),
      );
    });

    test('the position depends only on this device, so it takes no presenter clock', () {
      // This is the regression the file exists for, stated at the level it is
      // true. [audioPlayerPosition] has no parameter for the presenter's
      // timestamp, so no arithmetic here can consult it. Reconstructing the
      // position as `now - startedAtEpochMs` would jump an hour into a
      // three-minute track and play nothing at all.
      //
      // The widget-level half of the claim — that feeding wildly different
      // `startedAtEpochMs` values leaves the rendered position alone — is
      // covered in the rendering group below.
      const base = 65000;
      expect(
        audioPlayerPosition(baseMs: base, startedHere: t0, now: t0, durationMs: 180000),
        const Duration(milliseconds: base),
      );
    });

    test('the position never runs past the end of the track', () {
      expect(
        audioPlayerPosition(
          baseMs: 179000,
          startedHere: t0,
          now: t0.add(const Duration(seconds: 30)),
          durationMs: 180000,
        ),
        const Duration(milliseconds: 180000),
      );
    });

    test('a clock that steps backwards holds rather than rewinds', () {
      expect(
        audioPlayerPosition(
          baseMs: 65000,
          startedHere: t0,
          now: t0.subtract(const Duration(seconds: 5)),
          durationMs: 180000,
        ),
        const Duration(milliseconds: 65000),
      );
    });

    test('an unknown duration leaves the position unclamped', () {
      expect(
        audioPlayerPosition(
          baseMs: 0,
          startedHere: t0,
          now: t0.add(const Duration(minutes: 9)),
          durationMs: null,
        ),
        const Duration(minutes: 9),
      );
    });
  });

  group('finishing', () {
    test('a track that has run out stops itself', () {
      expect(
        audioPlayerHasFinished(position: const Duration(minutes: 3), durationMs: 180000, loop: false),
        isTrue,
      );
    });

    test('a track still running does not', () {
      expect(
        audioPlayerHasFinished(position: const Duration(minutes: 2), durationMs: 180000, loop: false),
        isFalse,
      );
    });

    test('a looping track is left to wrap on its own', () {
      // Stopping it at the end is exactly what a loop must not do.
      expect(
        audioPlayerHasFinished(position: const Duration(minutes: 5), durationMs: 180000, loop: true),
        isFalse,
      );
    });

    test('a track of unknown length is never declared finished', () {
      expect(
        audioPlayerHasFinished(position: const Duration(hours: 1), durationMs: null, loop: false),
        isFalse,
      );
    });
  });

  group('rendering', () {
    testWidgets('a player with no track says so', (tester) async {
      await tester.pumpWidget(wrap(player(fileId: '', title: '', durationMs: null)));

      expect(find.text('No track'), findsOneWidget);
    });

    testWidgets('renders on a surface that will not play it, as a mirror must', (tester) async {
      await tester.pumpWidget(wrap(
        player(startedAtEpochMs: DateTime.now().millisecondsSinceEpoch),
        policy: const SilentBoardAudioPolicy(),
      ));
      await tester.pump(const Duration(seconds: 1));

      // The scrubber still moves for the audience even though this surface is
      // silent — that is the whole point of separating position from playback.
      expect(find.text('Intro music'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrap(player(positionMs: 0)));
    });

    testWidgets('a presenter clock hours out still renders the position it was handed', (tester) async {
      // The widget-level half of the anchoring claim. Every one of these says
      // "playing, at 1:05"; only the presenter's wall clock differs, and it
      // differs by amounts that dwarf the track. If any of it were used to
      // reconstruct the position, these would not all agree.
      const positionMs = 65000;
      for (final startedAt in [
        DateTime.now().millisecondsSinceEpoch - const Duration(hours: 1).inMilliseconds,
        DateTime.now().millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch + const Duration(hours: 1).inMilliseconds,
        DateTime.now().millisecondsSinceEpoch + const Duration(days: 3).inMilliseconds,
      ]) {
        await tester.pumpWidget(wrap(
          player(positionMs: positionMs, startedAtEpochMs: startedAt),
          policy: const SilentBoardAudioPolicy(),
        ));

        expect(
          find.text('1:05'),
          findsOneWidget,
          reason: 'a presenter clock at $startedAt must not move where the track reads',
        );

        // A fresh element each round, so the next pump anchors from scratch
        // rather than keeping the position this one already counted from.
        await tester.pumpWidget(wrap(const SizedBox.shrink()));
      }
    });
  });
}
