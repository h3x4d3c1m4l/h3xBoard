import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/views/board_screen/components/widgets/dice_roll.dart';

/// The die's geometry and timing, tested as pure math.
///
/// Everything time-dependent lives here rather than in a widget test on purpose:
/// `tester.pump(duration)` advances the *fake* async clock, but `DateTime.now()`
/// does not move, so a widget test that starts a roll and settles would spin
/// until the timeout waiting on a clock it cannot advance. Passing `elapsedMs`
/// explicitly sidesteps that entirely and runs in milliseconds.
void main() {
  const halfBox = 90.0;

  void expectVec(Vec3 actual, Vec3 expected, {double tolerance = 1e-12, String? reason}) {
    expect((actual - expected).length, lessThan(tolerance), reason: reason ?? '$actual != $expected');
  }

  group('the die is a real die', () {
    test('opposite faces sum to seven', () {
      for (var face = 1; face <= 6; face++) {
        expectVec(
          kFaceNormals[face - 1],
          -kFaceNormals[7 - face - 1],
          reason: 'face $face should be opposite face ${7 - face}',
        );
      }
    });

    test('1, 2 and 3 run counter-clockwise around their shared corner', () {
      // The Western convention. Canvas y points down, which flips the visual
      // handedness, so the algebraic form is `cross(n1, n2) == -n3` — see the
      // comment on kFaceNormals. Assert it in the form that survives the flip.
      expectVec(kFaceNormals[0].cross(kFaceNormals[1]), -kFaceNormals[2]);
    });

    test('every face frame is orthonormal and right-handed', () {
      for (var i = 0; i < 6; i++) {
        final u = kFaceU[i];
        final v = kFaceV[i];
        final n = kFaceNormals[i];

        expect(u.length, closeTo(1, 1e-12), reason: 'u of face ${i + 1}');
        expect(v.length, closeTo(1, 1e-12), reason: 'v of face ${i + 1}');
        expect(n.length, closeTo(1, 1e-12), reason: 'n of face ${i + 1}');

        expect(u.dot(v).abs(), lessThan(1e-12), reason: 'u.v of face ${i + 1}');
        expect(u.dot(n).abs(), lessThan(1e-12), reason: 'u.n of face ${i + 1}');
        expect(v.dot(n).abs(), lessThan(1e-12), reason: 'v.n of face ${i + 1}');

        expectVec(u.cross(v), n, reason: 'face ${i + 1} is not right-handed');
      }
    });
  });

  group('the rest orientation', () {
    test('is a rotation', () {
      for (var face = 1; face <= 6; face++) {
        final r = restRotation(face);
        final ident = r * r.transposed;

        expect(ident.m00, closeTo(1, 1e-12));
        expect(ident.m11, closeTo(1, 1e-12));
        expect(ident.m22, closeTo(1, 1e-12));
        expect(ident.m01.abs(), lessThan(1e-12));
        expect(ident.m02.abs(), lessThan(1e-12));
        expect(ident.m12.abs(), lessThan(1e-12));
        expect(r.determinant, closeTo(1, 1e-12), reason: 'face $face must not be mirrored');
      }
    });

    test('lands every face upright, not just facing forward', () {
      // The whole point of deriving the rest pose from the pip frame. 1, 4 and 5
      // are symmetric under a quarter turn and would pass a facing-only test
      // however they were written; 2 and 3 are diagonals and 6 is two columns of
      // three, so for those this is the difference between a landed die and one
      // lying on its side.
      for (var face = 1; face <= 6; face++) {
        final r = restRotation(face);
        expectVec(r.apply(kFaceNormals[face - 1]), const Vec3(0, 0, 1), reason: 'face $face faces the camera');
        expectVec(r.apply(kFaceU[face - 1]), const Vec3(1, 0, 0), reason: 'face $face right is screen right');
        expectVec(r.apply(kFaceV[face - 1]), const Vec3(0, 1, 0), reason: 'face $face down is screen down');
      }
    });
  });

  group('the roll lands on the rolled face', () {
    test('exactly, at the end of the roll', () {
      for (var face = 1; face <= 6; face++) {
        for (var seed = 0; seed < 200; seed++) {
          expect(
            frontFaceOf(diceOrientation(face, seed, kDiceRollDurationMs)),
            face,
            reason: 'face $face, seed $seed',
          );
        }
      }
    });

    test('and stays landed through the whole settle window', () {
      // The residual spin is (0.1)^3 of its total by p = 0.9 — about 2 degrees —
      // and the rock peaks at kWobble on two axes. Both are far inside the 45
      // degrees at which the front-most face would flip. This is the test that
      // fails if someone raises kWobble or the spin range past what the landing
      // can absorb.
      const from = kDiceRollDurationMs * 90 ~/ 100;
      for (var face = 1; face <= 6; face++) {
        for (var seed = 0; seed < 40; seed++) {
          for (var t = from; t <= kDiceRollDurationMs; t += 5) {
            expect(
              frontFaceOf(diceOrientation(face, seed, t)),
              face,
              reason: 'face $face, seed $seed, ${t}ms',
            );
          }
        }
      }
    });

    test('is the presented rest orientation bit for bit once the roll is over', () {
      for (var face = 1; face <= 6; face++) {
        final rest = kPresentation * restRotation(face);
        final landed = diceOrientation(face, 7, kDiceRollDurationMs + 5000);
        expect(landed.m00, rest.m00);
        expect(landed.m11, rest.m11);
        expect(landed.m22, rest.m22);
      }
    });

    test('shows three faces once landed, so it reads as a cube', () {
      // A die turned square-on shows exactly one face, which is a tile. The
      // presentation tilt is what makes this widget worth having over the flat
      // one, so it is pinned rather than left to taste.
      for (var face = 1; face <= 6; face++) {
        final rotation = diceOrientation(face, 11, kDiceRollDurationMs);
        final visible = [
          for (var i = 0; i < 6; i++)
            if (isFrontFacing(rotation.apply(kFaceNormals[i]))) i + 1,
        ];
        expect(visible, hasLength(3), reason: 'face $face landed showing $visible');
        expect(visible, contains(face));
      }
    });

    test('does not start out already showing the answer', () {
      // Whole-turn spins would put the die at its rest pose at p = 0, showing the
      // result before it had rolled and then snapping into the tumble.
      var showingAnswerAtStart = 0;
      for (var seed = 0; seed < 200; seed++) {
        if (frontFaceOf(diceOrientation(3, seed, 0)) == 3) showingAnswerAtStart++;
      }
      expect(showingAnswerAtStart, lessThan(80), reason: 'the start pose should vary with the seed');
    });
  });

  group('determinism', () {
    test('orientation is a pure function of its arguments', () {
      for (var seed = 0; seed < 50; seed++) {
        final a = diceOrientation(4, seed, 613);
        final b = diceOrientation(4, seed, 613);
        expect(a.m00, b.m00);
        expect(a.m12, b.m12);
        expect(a.m21, b.m21);
      }
    });

    test('the mixer stays in range and does not walk by a constant', () {
      // rollSeed advances by one per roll, so consecutive seeds are the case that
      // matters. An affine mixer passes a "these two differ" check while stepping
      // by a fixed amount every time, which makes the tumble cycle every handful
      // of throws — so what is asserted here is that the *steps* vary, not just
      // the values.
      final steps = <int>{};
      var previous = diceMix(0, 1);
      for (var seed = 1; seed < 500; seed++) {
        final h = diceMix(seed, 1);
        expect(h, inInclusiveRange(0, 1048572));
        steps.add(h - previous);
        previous = h;
      }
      expect(steps.length, greaterThan(400), reason: 'the mixer is walking, not mixing');

      for (var seed = 0; seed < 200; seed++) {
        final a = spinFor(seed);
        final b = spinFor(seed + 1);
        expect((a - b).length, greaterThan(0.2), reason: 'seeds $seed and ${seed + 1} tumble alike');
      }
    });

    test('the integer draws are pinned, so the VM and dart2js agree', () {
      // Run this file with `--platform chrome` and these are the values that have
      // to come back. The presenter is a VM and a web viewer is dart2js, and the
      // numbers a mirror flashes through mid-roll are computed on each screen
      // rather than sent — so a divergence here is two people watching the same
      // board see different numbers.
      //
      // Only the integers are pinned. The orientation goes through sin and cos,
      // which neither dart:math nor JS Math is required to round identically, so
      // it is reproducible to within an ulp rather than bit for bit — invisible
      // at three decimal places of a rotation, and nowhere near the 0.5 margin
      // that decides which face is front-most.
      expect(
        [for (var seed = 0; seed < 6; seed++) diceMix(seed, 1)],
        [1033163, 134637, 167275, 82504, 928897, 609308],
      );
      expect(
        [for (var t = 0; t < kDiceRollDurationMs; t += 120) numberDiceValueAt(1, 20, 7, 42, t)],
        [18, 3, 5, 18, 1, 15, 6, 6, 6, 6],
      );
      expect(nextRollSeed(0xFFFFF), 0);
    });

    test('a null or future anchor reads as landed', () {
      expect(diceElapsedMs(null, 1000), kDiceRollDurationMs);
      expect(diceElapsedMs(5000, 1000), kDiceRollDurationMs, reason: 'a viewer clock running behind');
      expect(diceElapsedMs(1000, 1000), 0);
      expect(diceElapsedMs(1000, 1400), 400);
      expect(diceElapsedMs(1000, 99999), kDiceRollDurationMs);
    });

    test('the seed always advances, so a roll is never equal to its predecessor', () {
      var seed = 0;
      for (var i = 0; i < 5000; i++) {
        final next = nextRollSeed(seed);
        expect(next, isNot(seed));
        expect(next, greaterThanOrEqualTo(0));
        seed = next;
      }
    });
  });

  group('rendering invariants', () {
    test('the die never leaves its box, at any orientation', () {
      // The anti-clipping guarantee. Nothing downstream clips a CustomPaint, so
      // this is what stands between a roll and a die painting over its neighbours.
      for (var face = 1; face <= 6; face++) {
        for (var seed = 0; seed < 40; seed++) {
          for (var t = 0; t <= kDiceRollDurationMs; t += 17) {
            final rotation = diceOrientation(face, seed, t);
            final projected = projectedCube(rotation);
            final scale = fitScale(projected, halfBox);
            for (final q in projected) {
              expect(q.dx.abs() * scale, lessThanOrEqualTo(halfBox + 1e-9), reason: 'face $face seed $seed ${t}ms');
              expect(q.dy.abs() * scale, lessThanOrEqualTo(halfBox + 1e-9), reason: 'face $face seed $seed ${t}ms');
            }
          }
        }
      }
    });

    test('the resting size is an exact constant, not an emergent one', () {
      for (var face = 1; face <= 6; face++) {
        final scale = fitScale(projectedCube(diceOrientation(face, 3, kDiceRollDurationMs)), halfBox);
        expect(scale, closeTo(halfBox / kRestExtent, 1e-12), reason: 'face $face');
      }
    });

    test('the die shrinks while tumbling but not below two thirds', () {
      var min = double.infinity;
      for (var seed = 0; seed < 40; seed++) {
        for (var t = 0; t <= kDiceRollDurationMs; t += 11) {
          final scale = fitScale(projectedCube(diceOrientation(2, seed, t)), halfBox);
          min = math.min(min, scale / (halfBox / kRestExtent));
        }
      }
      expect(min, lessThan(0.99), reason: 'the toss should be visible');
      expect(min, greaterThan(0.6), reason: 'the die should not shrink to nothing');
    });

    test('one to three faces are visible, never two opposites', () {
      for (var face = 1; face <= 6; face++) {
        for (var seed = 0; seed < 40; seed++) {
          for (var t = 0; t <= kDiceRollDurationMs; t += 13) {
            final rotation = diceOrientation(face, seed, t);
            final visible = <int>[];
            for (var i = 0; i < 6; i++) {
              if (isFrontFacing(rotation.apply(kFaceNormals[i]))) visible.add(i + 1);
            }
            expect(visible.length, inInclusiveRange(1, 3), reason: 'face $face seed $seed ${t}ms: $visible');
            for (final v in visible) {
              expect(visible, isNot(contains(7 - v)), reason: 'both sides of $v visible');
            }
          }
        }
      }
    });

    test('a pip projects to an ellipse, not a circle', () {
      // The reason pips are polygons in the face frame rather than drawCircle at
      // the projected centre: on a tilted face they must foreshorten.
      final tilted = Mat3.rotY(0.9) * restRotation(1);
      final pip = pipPolygon(0, Offset.zero, tilted, 70);
      var minX = double.infinity, maxX = -double.infinity;
      var minY = double.infinity, maxY = -double.infinity;
      for (final q in pip) {
        minX = math.min(minX, q.dx);
        maxX = math.max(maxX, q.dx);
        minY = math.min(minY, q.dy);
        maxY = math.max(maxY, q.dy);
      }
      final aspect = (maxX - minX) / (maxY - minY);
      expect(aspect, lessThan(0.85), reason: 'a pip on a face tilted 51 degrees should be visibly narrower');
    });

    test('the number die tile stays in its box too, tilt included', () {
      // A tilted square reaches (cos + sin) of its half-width, so the pop and the
      // rock have to be budgeted against the resting size rather than each being
      // picked to look right on its own.
      for (var t = 0; t <= kDiceRollDurationMs; t += 3) {
        final pose = numberDicePoseAt(t);
        final reach = pose.scale * (math.cos(pose.tilt).abs() + math.sin(pose.tilt).abs());
        expect(reach, lessThanOrEqualTo(1.0), reason: '${t}ms overflows its box');
      }
      final landed = numberDicePoseAt(kDiceRollDurationMs);
      expect(landed.scale, kNumberDiceRest);
      expect(landed.tilt, 0.0, reason: 'the tile must settle square, not slightly askew');
    });

    test('shading is bounded and brightest toward the light', () {
      for (var i = 0; i < 6; i++) {
        expect(shadeOf(kFaceNormals[i]), inInclusiveRange(0.62, 1.0));
      }
      expect(shadeOf(kLight), greaterThan(shadeOf(-kLight)));
    });
  });

  group('the number die', () {
    test('lands exactly on its value', () {
      for (var seed = 0; seed < 200; seed++) {
        expect(numberDiceValueAt(1, 6, 4, seed, kDiceRollDurationMs), 4);
        expect(numberDiceValueAt(1, 6, 4, seed, kDiceRollDurationMs + 900), 4);
        expect(numberDiceValueAt(-5, 5, -2, seed, kDiceRollDurationMs), -2);
      }
    });

    test('stays inside the range for the whole roll', () {
      for (final (min, max) in const [(1, 6), (1, 100), (-20, -5), (0, 1), (7, 7)]) {
        for (var seed = 0; seed < 40; seed++) {
          for (var t = 0; t <= kDiceRollDurationMs; t += 7) {
            final v = numberDiceValueAt(min, max, max, seed, t);
            expect(v, inInclusiveRange(min, max), reason: '[$min, $max] seed $seed ${t}ms');
          }
        }
      }
    });

    test('visibly cycles rather than sitting still', () {
      for (var seed = 0; seed < 40; seed++) {
        var changes = 0;
        var previous = numberDiceValueAt(1, 6, 5, seed, 0);
        for (var t = 0; t <= kDiceRollDurationMs; t += 4) {
          final v = numberDiceValueAt(1, 6, 5, seed, t);
          if (v != previous) changes++;
          previous = v;
        }
        expect(changes, greaterThanOrEqualTo(5), reason: 'seed $seed barely moved');
      }
    });

    test('is a pure function, replayed identically on every mirror', () {
      for (var t = 0; t <= kDiceRollDurationMs; t += 29) {
        expect(numberDiceValueAt(3, 18, 11, 91, t), numberDiceValueAt(3, 18, 11, 91, t));
      }
    });

    test('a degenerate range is a constant, not a crash', () {
      for (var t = 0; t <= kDiceRollDurationMs; t += 100) {
        expect(numberDiceValueAt(4, 4, 4, 12, t), 4);
      }
      expect(drawValue(math.Random(1), 9, 9), 9);
      expect(drawValue(math.Random(1), 9, 2), 9);
    });
  });
}
