// ignore_for_file: cascade_invocations

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:h3xboard/extensions/canvas_extension.dart';

@Preview(name: 'Geodreieck Widget')
Widget myGeodreieckWidget() {
  return GeodreieckWidget();
}

class GeodreieckWidget extends StatelessWidget {

  const GeodreieckWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(size: const Size(160, 240), painter: _GeodreieckPainter()),
    );
  }

}

class _GeodreieckPainter extends CustomPainter {

  static double _deg2rad(int deg) => deg * (pi / 180);

  @override
  void paint(Canvas canvas, Size size) {
    Color color = const Color.fromARGB(255, 76, 0, 255);
    Color color2 = const Color.fromARGB(255, 255, 0, 0);
    Paint paint = Paint()..color = color..strokeWidth = 0.1;
    Paint paint2 = Paint()..color = color2..strokeWidth = 0.1;

    // Arc
    double strokeWidth = 3;
    double arcRadius = 50;
    final center = Offset(size.width / 2, 0);

    final yellowPaint = Paint()
      ..color = const Color(0xFFFFFF00)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcRadius),
      pi - _deg2rad(7),
      -pi + _deg2rad(14),
      false,
      yellowPaint,
    );

    // Borders
    canvas
      ..drawLine(Offset(0, 0.075), Offset(size.width, 0.075), paint)
      ..drawLine(Offset(0, 0), Offset(size.width / 2, size.width / 2), paint)
      ..drawLine(Offset(size.width, 0), Offset(size.width / 2, size.width / 2), paint);

    // Top milimeters
    for (int x = 10; x <= 150; x++) {
      if (x % 5 == 0) {
        canvas.drawLine(Offset(x.toDouble(), 0), Offset(x.toDouble(), 3.5), paint);
      } else {
        canvas.drawLine(Offset(x.toDouble(), 0), Offset(x.toDouble(), 2), paint);
      }

      if (x % 10 == 0) {
        TextPainter textPainter = TextPainter(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: ((x - 80).abs() ~/ 10).toString(),
            style: TextStyle(color: color, fontSize: 2.5),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter..layout()..paint(canvas, Offset(x - (0.5 * textPainter.width), 3.5));
      }
    }

    // Degrees
    for (int deg = 1; deg <= 179; deg++) {
      final double rad = _deg2rad(deg);
      var x = cos(rad), y = sin(rad);

      // Inner circle
      if (deg >= 5 && deg <= 175) {
        int end = deg % 5 == 0 ? 45 : 44; // Every 5th degree has a slightly longer line.
        canvas.drawLine(
          Offset(size.width / 2 + 43 * x, 43 * y),
          Offset(size.width / 2 + end * x, end * y),
          paint2,
        );
      }

      // Line from center to edge
      if (deg % 10 == 0) {
        final Offset lineStart = Offset(size.width / 2, 0);
        final Offset lineEnd = _degreeLineEndpoint(size, deg);
        final double startFraction = arcRadius / (lineEnd - lineStart).distance + 0.05;
        _drawDegreeLine(canvas, size, deg, startFraction, 1.0, paint);
      } else if (deg % 5 == 0) {
        _drawDegreeLine(canvas, size, deg, 0.94, 1.0, paint);
      } else {
        _drawDegreeLine(canvas, size, deg, 0.96, 1.0, paint);
      }

      // Degree label every 10°
      if (deg % 10 == 0) {
        _drawDegreeText(canvas, size, deg, deg.toString(), arcRadius - 0, color);
        _drawDegreeText(canvas, size, deg, (180 - deg).toString(), arcRadius - 3.5, color);
      }
    }
  }

  static Offset _degreeLineEndpoint(Size size, int deg) {
    final double rad = _deg2rad(deg);
    final Offset dir = Offset(cos(rad), sin(rad));
    final Offset start = Offset(size.width / 2, 0);
    final Offset end = start + dir;

    final Offset leftIntersection = lineIntersection(start, end, Offset(0, 0), Offset(size.width / 2, size.width / 2));
    final Offset rightIntersection = lineIntersection(start, end, Offset(size.width, 0), Offset(size.width / 2, size.width / 2));

    final double d1 = (leftIntersection - start).distance;
    final double d2 = (rightIntersection - start).distance;
    return d1 < d2 ? leftIntersection : rightIntersection;
  }

  void _drawDegreeLine(Canvas canvas, Size size, int deg, double startPercentage, double endPercentage, Paint paint) {
    final Offset start = Offset(size.width / 2, 0);
    final Offset end = _degreeLineEndpoint(size, deg);
    canvas.drawLine(
      start + (end - start) * startPercentage,
      start + (end - start) * endPercentage,
      paint,
    );
  }

  void _drawDegreeText(Canvas canvas, Size size, int deg, String text, double distanceFromCenter, Color color) {
    final double rad = _deg2rad(deg);
    final Offset start = Offset(size.width / 2, 0);
    final Offset position = start + Offset(cos(rad), sin(rad)) * distanceFromCenter;

    canvas.drawRotatedText(
      pivot: position,
      textPainter: TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 3)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      ),
      radians: _deg2rad(deg) - pi / 2,
    );
  }

  static Offset lineIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
    final dx1 = p2.dx - p1.dx;
    final dy1 = p2.dy - p1.dy;
    final dx2 = p4.dx - p3.dx;
    final dy2 = p4.dy - p3.dy;

    final determinant = dx1 * dy2 - dy1 * dx2;

    if (determinant == 0) throw Exception('No intersection');

    final t = ((p3.dx - p1.dx) * dy2 - (p3.dy - p1.dy) * dx2) / determinant;
    return Offset(p1.dx + t * dx1, p1.dy + t * dy1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

}
