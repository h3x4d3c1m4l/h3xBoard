import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/audio/audio_output_controller.dart';
import 'package:h3xboard/services/live_share/live_share_hub.dart';
import 'package:h3xboard/views/board_screen/components/widgets/hidden_widget_twin.dart';
import 'package:h3xboard/views/board_screen/components/widgets/sound_pad_widget.dart';
import 'package:h3xboard/views/components/board_audio_scope.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Where a board's sound is allowed to come out.
///
/// The rule this file exists to protect is that **exactly one surface plays at a
/// time**. Both failure directions are bad, and neither is loud in a test suite.
/// Too permissive and a clip comes out of an iPad and a classroom TV a beat
/// apart. Too strict and tapping a pad does nothing anywhere.
void main() {
  // The controller persists per device, so every test gets a clean store rather
  // than inheriting the choice the previous one made.
  setUp(() => SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty());

  Widget wrap(Widget child, BoardAudioPolicy policy) => FluentApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScaffoldPage(
          content: Center(
            child: SizedBox(
              width: 260,
              height: 300,
              child: BoardAudioScope(policy: policy, child: child),
            ),
          ),
        ),
      );

  group('ViewerBoardAudioPolicy needs both switches', () {
    ViewerBoardAudioPolicy policy({required bool routed, required bool enabledHere}) =>
        ViewerBoardAudioPolicy(presenterRoutedToViewers: () => routed, soundEnabledHere: () => enabledHere);

    test('plays only when the presenter routed to viewers AND this screen is armed', () {
      expect(policy(routed: true, enabledHere: true).playsHere, isTrue);
    });

    test('stays silent when the presenter kept audio on their own device', () {
      // Otherwise a viewer would echo whatever the presenter is already playing.
      expect(policy(routed: false, enabledHere: true).playsHere, isFalse);
    });

    test('stays silent on a screen nobody armed', () {
      // This is what keeps thirty student laptops quiet while one TV sounds.
      expect(policy(routed: true, enabledHere: false).playsHere, isFalse);
    });

    test('stays silent when neither holds', () {
      expect(policy(routed: false, enabledHere: false).playsHere, isFalse);
    });
  });

  test('the external display never plays, because it shares the host sound card', () {
    // Playing here would double the presenter's audio rather than move it.
    expect(const SilentBoardAudioPolicy().playsHere, isFalse);
  });

  group('BoardAudioScope.of picks the surface, then the app, then silence', () {
    // The single point where "exactly one surface plays" is decided. Both of its
    // fallbacks are invisible until they are wrong, so each is pinned here.
    tearDown(() {
      if (GetIt.I.isRegistered<AudioOutputController>()) GetIt.I.unregister<AudioOutputController>();
    });

    testWidgets('a surface that states its own policy wins over the app-wide one', (tester) async {
      // A viewer with its sound off must stay quiet even while the presenter's
      // own controller says this device plays.
      GetIt.I.registerSingleton<AudioOutputController>(AudioOutputController(
        isSharing: () => false,
        viewerCount: () => 0,
        hub: LiveShareHub(),
      ));
      late BoardAudioPolicy resolved;

      await tester.pumpWidget(wrap(
        Builder(builder: (context) {
          resolved = BoardAudioScope.of(context);
          return const SizedBox.shrink();
        }),
        const SilentBoardAudioPolicy(),
      ));

      expect(resolved.playsHere, isFalse);
    });

    testWidgets('outside a scope it falls back to the app-wide routing', (tester) async {
      GetIt.I.registerSingleton<AudioOutputController>(AudioOutputController(
        isSharing: () => false,
        viewerCount: () => 0,
        hub: LiveShareHub(),
      ));
      late BoardAudioPolicy resolved;

      await tester.pumpWidget(FluentApp(
        home: Builder(builder: (context) {
          resolved = BoardAudioScope.of(context);
          return const SizedBox.shrink();
        }),
      ));

      // Not sharing, so the presenter's own device is the one that plays.
      expect(resolved, isA<PresenterBoardAudioPolicy>());
      expect(resolved.playsHere, isTrue);
    });

    testWidgets('with no scope and no app services at all, the answer is silence', (tester) async {
      // The external-display isolate outside a scope. Guessing "play" here is
      // the failure people notice: the same clip out of two speakers at once.
      late BoardAudioPolicy resolved;

      await tester.pumpWidget(FluentApp(
        home: Builder(builder: (context) {
          resolved = BoardAudioScope.of(context);
          return const SizedBox.shrink();
        }),
      ));

      expect(resolved.playsHere, isFalse);
    });
  });

  group('AudioOutputController', () {
    AudioOutputController create({
      required bool isSharing,
      required int viewerCount,
      LiveShareHub? hub,
    }) =>
        AudioOutputController(
          isSharing: () => isSharing,
          viewerCount: () => viewerCount,
          hub: hub ?? LiveShareHub(),
        );

    test('defaults to this device', () {
      final controller = create(isSharing: false, viewerCount: 0);

      expect(controller.preferred, AudioOutput.thisDevice);
      expect(controller.playsHere, isTrue);
    });

    test('routes to the shared screen once one is watching', () async {
      final controller = create(isSharing: true, viewerCount: 1);
      await controller.setPreferred(AudioOutput.sharedScreen);

      expect(controller.effectiveOutput, AudioOutput.sharedScreen);
      expect(controller.playsHere, isFalse);
      expect(controller.isFallingBackToThisDevice, isFalse);
    });

    test('falls back to this device when not sharing at all', () async {
      final controller = create(isSharing: false, viewerCount: 0);
      await controller.setPreferred(AudioOutput.sharedScreen);

      // Losing a sound mid-lesson with no explanation is worse than hearing it
      // from the wrong speaker, so this reports rather than goes quiet.
      expect(controller.playsHere, isTrue);
      expect(controller.isFallingBackToThisDevice, isTrue);
    });

    test('falls back when sharing but nothing is watching', () async {
      final controller = create(isSharing: true, viewerCount: 0);
      await controller.setPreferred(AudioOutput.sharedScreen);

      expect(controller.playsHere, isTrue);
      expect(controller.isFallingBackToThisDevice, isTrue);
    });

    test('publishes the preference, not the fallback', () async {
      // Publishing the fallback would mean one viewer arriving a moment late
      // silenced the whole session. The presenter would still be announcing
      // "audio is mine" long after a screen showed up ready to play the clip.
      final hub = LiveShareHub();
      final sink = _RecordingSink();
      hub.addSink(sink);

      final controller = create(isSharing: false, viewerCount: 0, hub: hub);
      await controller.setPreferred(AudioOutput.sharedScreen);

      expect(controller.isFallingBackToThisDevice, isTrue, reason: 'no screen is watching');
      expect(sink.audioFrames.single.toViewers, isTrue, reason: 'but viewers must still be told');
      expect(controller.toViewers, isTrue);
    });

    test('re-selecting the current output publishes nothing', () async {
      final hub = LiveShareHub();
      final sink = _RecordingSink();
      hub.addSink(sink);

      final controller = create(isSharing: true, viewerCount: 1, hub: hub);
      await controller.setPreferred(AudioOutput.thisDevice);

      expect(sink.audioFrames, isEmpty);
    });

    test('remembers the choice across a restart of the app', () async {
      final first = create(isSharing: true, viewerCount: 1);
      await first.setPreferred(AudioOutput.sharedScreen);

      final second = create(isSharing: true, viewerCount: 1);
      await second.load();

      // Per device rather than per board: it describes the room you are in.
      expect(second.preferred, AudioOutput.sharedScreen);
    });
  });

  group('a pad honours its surface', () {
    Widget pad({required int triggerSeed}) => SoundPadWidget(
          fileId: 'f1',
          label: 'Applause',
          emoji: '👏',
          volume: 1,
          triggerSeed: triggerSeed,
          stopSeed: 0,
          onTrigger: () {},
          onStop: () {},
        );

    testWidgets('a trigger this surface will not play still confirms it went out', (tester) async {
      const policy = SilentBoardAudioPolicy();
      await tester.pumpWidget(wrap(pad(triggerSeed: 0), policy));

      expect(find.byIcon(LucideIcons.tv), findsNothing);

      // The same seed change a mirror would see arriving from the presenter.
      await tester.pumpWidget(wrap(pad(triggerSeed: 1), policy));
      await tester.pump();

      // Not a progress bar: this device cannot observe whether the screen
      // actually made a sound, so it must not draw something that implies it.
      expect(find.byIcon(LucideIcons.tv), findsOneWidget);
    });

    testWidgets('the confirmation clears itself', (tester) async {
      const policy = SilentBoardAudioPolicy();
      await tester.pumpWidget(wrap(pad(triggerSeed: 0), policy));
      await tester.pumpWidget(wrap(pad(triggerSeed: 1), policy));
      await tester.pump();
      expect(find.byIcon(LucideIcons.tv), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(LucideIcons.tv), findsNothing);
    });

    testWidgets('a trigger on a playing surface attempts playback instead of flashing', (tester) async {
      // No audio device in a test runner, so the sound never starts. What is
      // asserted is that the pad took the play path rather than the "sent" path.
      final policy = ViewerBoardAudioPolicy(
        presenterRoutedToViewers: () => true,
        soundEnabledHere: () => true,
      );
      await tester.pumpWidget(wrap(pad(triggerSeed: 0), policy));
      await tester.pumpWidget(wrap(pad(triggerSeed: 1), policy));
      await tester.pump();

      expect(find.byIcon(LucideIcons.tv), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the hidden twin of a full-screen pad', () {
    // While a widget flies to and from full screen it is alive twice. One copy
    // is on screen; the other stays on the board for the flight to land on.
    // Both are handed the same config, so both see a trigger seed change.
    // Acting on it twice plays every tap twice.
    Widget pad({required int triggerSeed}) => SoundPadWidget(
          fileId: 'f1',
          label: 'Applause',
          emoji: '👏',
          volume: 1,
          triggerSeed: triggerSeed,
          stopSeed: 0,
          onTrigger: () {},
          onStop: () {},
        );

    /// Both copies of one pad, exactly as the board builds them while flying:
    /// the twin wrapped by [HiddenWidgetTwin], the visible one not.
    Widget bothCopies({required int triggerSeed, required BoardAudioPolicy policy}) => wrap(
          Column(
            children: [
              Expanded(child: HiddenWidgetTwin(isTwin: true, child: pad(triggerSeed: triggerSeed))),
              Expanded(child: HiddenWidgetTwin(isTwin: false, child: pad(triggerSeed: triggerSeed))),
            ],
          ),
          policy,
        );

    testWidgets('acts on nothing, so a tap is not confirmed twice', (tester) async {
      // A silent surface is the one that shows an observable effect: the "sent
      // to screen" badge. One badge means one copy acted; two means the bug.
      const policy = SilentBoardAudioPolicy();
      await tester.pumpWidget(bothCopies(triggerSeed: 0, policy: policy));

      await tester.pumpWidget(bothCopies(triggerSeed: 1, policy: policy));
      await tester.pump();

      expect(find.byIcon(LucideIcons.tv), findsOneWidget);
    });

    testWidgets('the copy on screen still acts, so the fix does not silence both', (tester) async {
      // The over-correction this guards against: making the twin inert by
      // muting the whole subtree would take the visible copy with it.
      const policy = SilentBoardAudioPolicy();
      await tester.pumpWidget(wrap(HiddenWidgetTwin(isTwin: false, child: pad(triggerSeed: 0)), policy));

      await tester.pumpWidget(wrap(HiddenWidgetTwin(isTwin: false, child: pad(triggerSeed: 1)), policy));
      await tester.pump();

      expect(find.byIcon(LucideIcons.tv), findsOneWidget);
    });

    testWidgets('a twin alone does nothing at all', (tester) async {
      const policy = SilentBoardAudioPolicy();
      await tester.pumpWidget(wrap(HiddenWidgetTwin(isTwin: true, child: pad(triggerSeed: 0)), policy));

      await tester.pumpWidget(wrap(HiddenWidgetTwin(isTwin: true, child: pad(triggerSeed: 1)), policy));
      await tester.pump();

      expect(find.byIcon(LucideIcons.tv), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a non-twin passes the surface policy straight through', (tester) async {
      // The wrapper is in the tree whether or not it is the twin, so it must be
      // transparent when it isn't: a playing surface must still play.
      final policy = ViewerBoardAudioPolicy(
        presenterRoutedToViewers: () => true,
        soundEnabledHere: () => true,
      );
      await tester.pumpWidget(wrap(HiddenWidgetTwin(isTwin: false, child: pad(triggerSeed: 0)), policy));

      await tester.pumpWidget(wrap(HiddenWidgetTwin(isTwin: false, child: pad(triggerSeed: 1)), policy));
      await tester.pump();

      // Took the play path, not the "sent to screen" one.
      expect(find.byIcon(LucideIcons.tv), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('becoming the twin and back does not rebuild the pad', (tester) async {
      // Why the wrapper is unconditional: inserting it around the child only
      // while flying would reparent the subtree, destroying the State the
      // flight exists to preserve.
      const policy = SilentBoardAudioPolicy();
      await tester.pumpWidget(wrap(HiddenWidgetTwin(isTwin: false, child: pad(triggerSeed: 0)), policy));
      final before = tester.state(find.byType(SoundPadWidget));

      await tester.pumpWidget(wrap(HiddenWidgetTwin(isTwin: true, child: pad(triggerSeed: 0)), policy));
      await tester.pumpWidget(wrap(HiddenWidgetTwin(isTwin: false, child: pad(triggerSeed: 0)), policy));

      expect(tester.state(find.byType(SoundPadWidget)), same(before));
    });
  });
}

class _RecordingSink implements LiveShareSink {

  final List<LiveShareMessage> messages = [];

  List<LiveShareAudioOutput> get audioFrames => messages.whereType<LiveShareAudioOutput>().toList();

  @override
  void send(LiveShareMessage message) => messages.add(message);

}
