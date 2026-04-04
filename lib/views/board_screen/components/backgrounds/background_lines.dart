import 'package:flutter/material.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';

class BackgroundLines extends StatelessWidget {

  final BoardLines lines;
  final double density;
  final Color color;
  final Widget? child;

  const BackgroundLines({
    super.key,
    required this.lines,
    required this.density,
    required this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (lines == .none) return child ?? const SizedBox();

    return CustomPaint(
      painter: _BackgroundLinesPainter(lines: lines, density: density, color: color),
      child: child,
    );
  }

}

class _BackgroundLinesPainter extends CustomPainter {

  final BoardLines lines;
  final double density;
  final Color color;

  _BackgroundLinesPainter({required this.lines, required this.density, required this.color})
    : assert(lines != .none, 'Painter should not be invoked if there are no lines to paint.');

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = color;
    for (double y = density; y < size.height; y += density) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    if (lines == BoardLines.grid) {
      for (double x = density; x < size.width; x += density) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BackgroundLinesPainter oldDelegate) =>
      lines != oldDelegate.lines || density != oldDelegate.density || color != oldDelegate.color;

}
