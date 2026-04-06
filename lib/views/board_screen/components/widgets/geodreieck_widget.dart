// ignore_for_file: cascade_invocations

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

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

  @override
  void paint(Canvas canvas, Size size) {
    double deg2rad(int deg) => deg * (pi / 180);

    Color color = const Color.fromARGB(255, 76, 0, 255);
    Paint paint = Paint()..color = color..strokeWidth = 0.1;

    // Arc
    // Paint yellowPaint = Paint()..color = Color(0xFFFFFF00)..strokeWidth = 3;
    // canvas.drawArc(
    //   Rect.fromCenter(center: Offset(size.width / 2, 0) , width: size.width, height: size.width), 0, -1.5 * pi, false, yellowPaint,
    // );

    // Borders
    canvas
      ..drawLine(Offset(0, 0), Offset(size.width, 0), paint)
      ..drawLine(Offset(0, 0), Offset(size.width / 2, size.width / 2), paint)
      ..drawLine(Offset(size.width, 0), Offset(size.width / 2, size.width / 2), paint);

    // Top milimeters
    for (int x = 10; x <= 150; x++) {
      if (x % 5 == 0) {
        canvas.drawLine(Offset(x.toDouble(), 0), Offset(x.toDouble(), 5), paint);
      } else {
        canvas.drawLine(Offset(x.toDouble(), 0), Offset(x.toDouble(), 3), paint);
      }

      if (x % 10 == 0) {
        TextPainter textPainter = TextPainter(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: ((x - 80).abs() ~/ 10).toString(),
            style: TextStyle(color: color, fontSize: 3),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter..layout()..paint(canvas, Offset(x - (0.5 * textPainter.width), 5));
      }
    }

    // Degrees
    for (int deg = 1; deg <= 179; deg++) {
      var x = cos(deg2rad(deg)), y = sin(deg2rad(deg));

      // Inner circle
      if (deg >= 5 && deg <= 175) {
        int end = deg % 5 == 0 ? 47 : 46; // Every 5th degree has a slightly longer line.
        canvas.drawLine(
          Offset(size.width / 2 + 44 * x, 44 * y),
          Offset(size.width / 2 + end * x, end * y),
          paint,
        );
      }

      final double rad = deg2rad(deg);

      final Offset dir = Offset(cos(rad), sin(rad));

      final Offset start = Offset(80, 0);
      final Offset end = start + dir;

      final Offset leftIntersection = lineIntersection(start, end, Offset(0, 0), Offset(80, 80));
      final Offset rightIntersection = lineIntersection(start, end, Offset(160, 0), Offset(80, 80));

      final double d1 = (leftIntersection - start).distance;
      final double d2 = (rightIntersection - start).distance;
      final Offset hit = d1 < d2 ? leftIntersection : rightIntersection;

      canvas.drawLine(start, hit, paint);
    }
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
