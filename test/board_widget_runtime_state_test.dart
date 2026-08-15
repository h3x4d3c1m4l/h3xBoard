import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/dice_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/number_dice_widget.dart';

/// Which config changes count as ephemeral runtime state.
///
/// This is the switch that decides whether a change reaches the external mirror
/// *and* the undo stack, or only the mirror. Getting it wrong is silent in both
/// directions: too narrow and every dice roll buries the board's real edits under
/// undo entries, too wide and a genuine edit becomes un-undoable.
void main() {
  // Fixed seeds so a roll that happens to land on the value it started from
  // doesn't make this flaky — the point being tested is the classification, not
  // the draw.
  final random = math.Random(7);

  group('a dice roll is runtime state', () {
    test('rolling is runtime-only, so it mirrors without entering undo history', () {
      const before = DiceConfig();
      for (var i = 0; i < 50; i++) {
        final after = rollDice(before, random: random, nowMs: 1000 + i);
        expect(isWidgetRuntimeOnlyChange(before, after), isTrue, reason: 'roll $i');
      }
    });

    test('a roll always differs from the config it came from', () {
      // isWidgetRuntimeOnlyChange requires old != new, so a roll that produced an
      // identical config would fall through to the undoable branch and push an
      // empty history entry — reachable by double-tapping the die. The advancing
      // seed is what closes that.
      var config = const DiceConfig();
      for (var i = 0; i < 200; i++) {
        // Same millisecond every time: the worst case, not the typical one.
        final rolled = rollDice(config, random: random, nowMs: 5000);
        expect(rolled, isNot(config), reason: 'roll $i produced an identical config');
        config = rolled;
      }
    });

    test('changing the style is a real edit', () {
      const before = DiceConfig();
      final after = before.copyWith(style: DiceStyle.red);
      expect(isWidgetRuntimeOnlyChange(before, after), isFalse);
    });

    test('a style change during a roll is still a real edit', () {
      const before = DiceConfig(face: 5, rollSeed: 3, rolledAtEpochMs: 1000);
      final after = before.copyWith(style: DiceStyle.slate);
      expect(isWidgetRuntimeOnlyChange(before, after), isFalse);
    });
  });

  group('the number die', () {
    test('rolling is runtime-only', () {
      const before = NumberDiceConfig();
      for (var i = 0; i < 50; i++) {
        final after = rollNumberDice(before, random: random, nowMs: 1000 + i);
        expect(isWidgetRuntimeOnlyChange(before, after), isTrue, reason: 'roll $i');
        expect(after.value, inInclusiveRange(before.min, before.max));
      }
    });

    test('changing the range is a real edit, even when it clamps the value', () {
      // The case the value sentinel in clearWidgetRuntimeState exists for: the
      // range moves and drags the showing value with it, and the whole thing must
      // still read as one undoable edit rather than as a roll.
      const before = NumberDiceConfig(value: 6);
      final after = before.copyWith(min: 10, max: 20, value: 10);
      expect(isWidgetRuntimeOnlyChange(before, after), isFalse);
    });

    test('a roll never leaves the range', () {
      for (final (min, max) in const [(1, 6), (0, 1), (-9, -3), (4, 4), (1, 1000)]) {
        final config = NumberDiceConfig(min: min, max: max, value: min);
        for (var i = 0; i < 200; i++) {
          expect(rollNumberDice(config, random: random).value, inInclusiveRange(min, max));
        }
      }
    });
  });

  group('the widgets that were already runtime-stateful still are', () {
    test('a stopwatch tick is runtime-only, changing its display is not', () {
      const paused = StopwatchConfig();
      expect(isWidgetRuntimeOnlyChange(paused, paused.copyWith(startedAtEpochMs: 1000)), isTrue);
      expect(isWidgetRuntimeOnlyChange(paused, paused.copyWith(elapsedMs: 4200)), isTrue);
      expect(isWidgetRuntimeOnlyChange(paused, paused.copyWith(showCentiseconds: false)), isFalse);
    });

    test('a timer anchor is runtime-only, changing its duration is not', () {
      const idle = TimerConfig();
      expect(isWidgetRuntimeOnlyChange(idle, idle.copyWith(startedAtEpochMs: 1000)), isTrue);
      expect(isWidgetRuntimeOnlyChange(idle, idle.copyWith(durationSeconds: 60)), isFalse);
    });
  });

  test('widgets without runtime state are never classified as runtime-only', () {
    const note = MemoNoteConfig();
    expect(isWidgetRuntimeOnlyChange(note, note.copyWith(text: 'hello')), isFalse);
    expect(isWidgetRuntimeOnlyChange(note, note.copyWith(color: MemoNoteColor.blue)), isFalse);

    const light = TrafficLightConfig();
    expect(isWidgetRuntimeOnlyChange(light, light.copyWith(activeLight: TrafficLightColor.green)), isFalse);
  });

  test('an unchanged config is not a change at all', () {
    const config = DiceConfig(face: 2, rollSeed: 9, rolledAtEpochMs: 1234);
    expect(isWidgetRuntimeOnlyChange(config, config), isFalse);
  });

  test('configs of different types are never comparable', () {
    expect(isWidgetRuntimeOnlyChange(const DiceConfig(), const NumberDiceConfig()), isFalse);
  });
}
