import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/dice_roll.dart';
import 'package:h3xboard/views/board_screen/components/widgets/dice_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/number_dice_widget.dart';

/// What the dice widgets add on top of the math in dice_roll_test.dart: the tap,
/// and when the ticker runs.
///
/// Deliberately thin on anything time-dependent. `tester.pump(duration)` advances
/// the *fake* async clock, but the roll is anchored to `DateTime.now()`, which a
/// test cannot move — so the tumble itself is tested as pure math and what's left
/// here is the wiring.
Widget _host(Widget child) => FluentApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: FluentThemeData(accentColor: kAccentColor.toAccentColor()),
      home: Center(child: child),
    );

Future<void> _pump(WidgetTester tester, BoardWidgetConfig config, void Function(BoardWidgetConfig) onChange) {
  final descriptor = descriptorFor(config);
  return tester.pumpWidget(_host(
    SizedBox.fromSize(
      size: descriptor.naturalSize(config),
      child: descriptor.buildWidget(config, onChange),
    ),
  ));
}

void main() {
  // Long past, so every widget built from it is already landed and still.
  const landedAnchor = 1000;

  group('tapping a die rolls it', () {
    testWidgets('one tap emits exactly one roll', (tester) async {
      const config = DiceConfig(face: 2, rollSeed: 4, rolledAtEpochMs: landedAnchor);
      final emitted = <BoardWidgetConfig>[];
      await _pump(tester, config, emitted.add);

      await tester.tap(find.byType(DiceWidget));
      await tester.pump();

      expect(emitted, hasLength(1));
      final rolled = emitted.single as DiceConfig;
      expect(rolled.face, inInclusiveRange(1, 6));
      expect(rolled.rollSeed, nextRollSeed(config.rollSeed));
      expect(rolled.rolledAtEpochMs, greaterThan(landedAnchor));
      expect(rolled.style, config.style, reason: 'a roll should not touch anything else');
    });

    testWidgets('the number die rolls inside its range', (tester) async {
      const config = NumberDiceConfig(min: 10, max: 12, value: 10, rolledAtEpochMs: landedAnchor);
      final emitted = <BoardWidgetConfig>[];
      await _pump(tester, config, emitted.add);

      await tester.tap(find.byType(NumberDiceWidget));
      await tester.pump();

      expect(emitted, hasLength(1));
      final rolled = emitted.single as NumberDiceConfig;
      expect(rolled.value, inInclusiveRange(10, 12));
      expect(rolled.min, 10);
      expect(rolled.max, 12);
    });

    testWidgets('a mirror cannot originate a roll', (tester) async {
      // The no-op callback is exactly what read_only_board.dart hands every
      // mirror. A viewer's tap has to go nowhere, while the tumble it is already
      // showing carries on from the anchor.
      const config = DiceConfig(face: 3, rollSeed: 2, rolledAtEpochMs: landedAnchor);
      await _pump(tester, config, (_) {});

      await tester.tap(find.byType(DiceWidget));
      await tester.pump();

      expect(tester.widget<DiceWidget>(find.byType(DiceWidget)).face, 3);
      expect(tester.takeException(), isNull);
    });
  });

  group('the ticker only runs while a roll is in the air', () {
    testWidgets('a die that has never been rolled is still', (tester) async {
      // Load-bearing: the catalog preview and the registry sweep in
      // board_widget_surface_test.dart both build every widget from its default
      // config, and a die that animated there would cost them a live ticker each.
      await _pump(tester, const DiceConfig(), (_) {});
      await tester.pumpAndSettle();

      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(descriptorFor(const DiceConfig()).defaultConfig, isA<DiceConfig>());
    });

    testWidgets('a landed die is still', (tester) async {
      await _pump(tester, const NumberDiceConfig(rolledAtEpochMs: landedAnchor), (_) {});
      await tester.pumpAndSettle();

      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a fresh anchor starts it, and a landed one stops it again', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _pump(tester, DiceConfig(rolledAtEpochMs: now), (_) {});

      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'a roll in flight should be animating');

      // Swapping in a landed anchor is also how the ticker gets stopped before
      // teardown — SingleTickerProviderStateMixin throws if it is disposed active.
      await _pump(tester, const DiceConfig(rolledAtEpochMs: landedAnchor), (_) {});
      await tester.pumpAndSettle();

      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('rendering', () {
    testWidgets('a landed number die shows its value', (tester) async {
      await _pump(tester, const NumberDiceConfig(min: 1, max: 20, value: 17, rolledAtEpochMs: landedAnchor), (_) {});
      await tester.pumpAndSettle();

      expect(find.text('17'), findsOneWidget);
    });

    testWidgets('a negative range renders', (tester) async {
      await _pump(tester, const NumberDiceConfig(min: -10, max: -1, value: -7, rolledAtEpochMs: landedAnchor), (_) {});
      await tester.pumpAndSettle();

      expect(find.text('-7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every die style paints without error', (tester) async {
      for (final style in DiceStyle.values) {
        for (var face = 1; face <= 6; face++) {
          await _pump(tester, DiceConfig(face: face, style: style, rolledAtEpochMs: landedAnchor), (_) {});
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$style face $face');
        }
      }
    });
  });
}
