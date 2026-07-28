import 'dart:convert';
import 'dart:ui';

import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/services/drawing/arrow_line.dart';
import 'package:h3xboard/services/drawing_serialization.dart';

/// Sends [json] through the same encode/decode the server relay does, which is
/// where whole-number doubles collapse to ints (JSON stores `1.0` and `1`
/// identically) — the exact case [restoreDrawingContents] normalizes.
Map<String, dynamic> _throughTheWire(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group('restoreDrawingContents', () {
    test('rehydrates an ArrowLine with whole-number coordinates', () {
      final arrow = ArrowLine.data(
        // Whole numbers on purpose: these come back from the wire as ints and
        // must be coerced to double before the package's `as double` casts.
        startPoint: const Offset(100, 200),
        endPoint: const Offset(300, 400),
        paint: Paint()
          ..color = const Color(0xFF00FF00)
          ..strokeWidth = 4,
      );

      final restored = restoreDrawingContents([_throughTheWire(arrow.toJson())]);

      expect(restored, hasLength(1));
      final result = restored.single as ArrowLine;
      expect(result.startPoint, const Offset(100, 200));
      expect(result.endPoint, const Offset(300, 400));
      expect(result.paint.color, const Color(0xFF00FF00));
      expect(result.paint.strokeWidth, 4.0);
    });

    test('rehydrates the shape types the shape tool draws', () {
      // Driven through a real drag, so the JSON under test is what the app
      // writes rather than a hand-rolled approximation of it.
      final shapes = <PaintContent>[StraightLine(), Rectangle(), Circle(), ArrowLine()];
      final strokes = shapes.map((shape) {
        shape
          ..paint = (Paint()..strokeWidth = 4)
          ..startDraw(const Offset(100, 200))
          ..drawing(const Offset(300, 400));
        return _throughTheWire(shape.toJson());
      }).toList();

      final restored = restoreDrawingContents(strokes);

      expect(restored.map((c) => c.contentType), [
        'StraightLine',
        'Rectangle',
        'Circle',
        'ArrowLine',
      ]);
    });

    test('drops an unknown stroke type instead of throwing', () {
      // Forward compatibility: a build that predates a new stroke type must skip
      // it, not crash the whole board.
      final restored = restoreDrawingContents([
        {'type': 'SomethingFromTheFuture', 'startPoint': {'dx': 1, 'dy': 2}},
      ]);

      expect(restored, isEmpty);
    });
  });
}
