import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:flutter_drawing_board/paint_extension.dart';

// Head length is a multiple of the stroke width, floored so a thin 2px line still
// gets a head readable from the back of a classroom; width is relative to length.
const double _kHeadLengthFactor = 6;
const double _kHeadWidthFactor = 0.8;
const double _kMinHeadLength = 16;

/// A straight line with a filled triangular head at its end point.
///
/// The drawing package ships [StraightLine], [Rectangle] and [Circle] but no
/// arrow. This follows [StraightLine]'s JSON shape exactly, so
/// `restoreDrawingContents` needs nothing beyond an `'ArrowLine'` case — the
/// `dx`/`dy` keys it nests under are already normalized there.
class ArrowLine extends PaintContent {

  ArrowLine();

  ArrowLine.data({
    required this.startPoint,
    required this.endPoint,
    required Paint paint,
  }) : super.paint(paint);

  factory ArrowLine.fromJson(Map<String, dynamic> data) {
    return ArrowLine.data(
      startPoint: jsonToOffset(data['startPoint'] as Map<String, dynamic>),
      endPoint: jsonToOffset(data['endPoint'] as Map<String, dynamic>),
      paint: jsonToPaint(data['paint'] as Map<String, dynamic>),
    );
  }

  Offset? startPoint;
  Offset? endPoint;

  @override
  String get contentType => 'ArrowLine';

  @override
  void startDraw(Offset startPoint) => this.startPoint = startPoint;

  @override
  void drawing(Offset nowPoint) => endPoint = nowPoint;

  @override
  void draw(Canvas canvas, Size size, bool deeper) {
    final start = startPoint;
    final end = endPoint;
    if (start == null || end == null) return;

    final delta = end - start;
    final length = delta.distance;
    // A zero-length drag has no direction to point in, and dividing by it below
    // would give a NaN direction.
    if (length == 0) return;

    final headLength = math.max(paint.strokeWidth * _kHeadLengthFactor, _kMinHeadLength);
    // Never let the head swallow the whole arrow on a very short drag.
    final clampedHead = math.min(headLength, length);
    final direction = delta / length;
    final headBase = end - direction * clampedHead;
    // Perpendicular to the shaft, scaled to half the head's width.
    final normal = Offset(-direction.dy, direction.dx) * (clampedHead * _kHeadWidthFactor / 2);

    // The shaft stops at the head's base so a translucent (highlighter-alpha)
    // arrow doesn't double-darken where the two overlap.
    final shaftPaint = Paint()
      ..color = paint.color
      ..blendMode = paint.blendMode
      ..isAntiAlias = paint.isAntiAlias
      ..strokeCap = StrokeCap.round
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, headBase, shaftPaint);

    final headPaint = Paint()
      ..color = paint.color
      ..blendMode = paint.blendMode
      ..isAntiAlias = paint.isAntiAlias
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(headBase.dx + normal.dx, headBase.dy + normal.dy)
        ..lineTo(headBase.dx - normal.dx, headBase.dy - normal.dy)
        ..close(),
      headPaint,
    );
  }

  @override
  ArrowLine copy() => ArrowLine();

  @override
  Map<String, dynamic> toContentJson() {
    return <String, dynamic>{
      'startPoint': startPoint?.toJson(),
      'endPoint': endPoint?.toJson(),
      'paint': paint.toJson(),
    };
  }

}
