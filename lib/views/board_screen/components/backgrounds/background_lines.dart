import 'package:flutter/widgets.dart';
import 'package:h3xboard/models/board.dart';

class BackgroundLines extends StatelessWidget {

  final BoardLinePattern pattern;
  final double spacing;
  final Color color;
  final Widget? child;

  const BackgroundLines({
    super.key,
    required this.pattern,
    required this.spacing,
    required this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (pattern == .none) return child ?? const SizedBox();

    return CustomPaint(
      painter: _BackgroundLinesPainter(pattern: pattern, spacing: spacing, color: color),
      child: child,
    );
  }

}

class _BackgroundLinesPainter extends CustomPainter {

  final BoardLinePattern pattern;
  final double spacing;
  final Color color;

  _BackgroundLinesPainter({required this.pattern, required this.spacing, required this.color})
    : assert(pattern != .none, 'Painter should not be invoked if there are no lines to paint.');

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = color;

    // Dots: a dot at each grid intersection instead of full lines.
    if (pattern == BoardLinePattern.dots) {
      // Scale the dot to the spacing so it stays proportional as the grid changes.
      final radius = (spacing * 0.06).clamp(1.0, 4.0);
      for (double y = spacing; y < size.height; y += spacing) {
        for (double x = spacing; x < size.width; x += spacing) {
          canvas.drawCircle(Offset(x, y), radius, paint);
        }
      }
      return;
    }

    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    if (pattern == BoardLinePattern.grid) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BackgroundLinesPainter oldDelegate) =>
      pattern != oldDelegate.pattern || spacing != oldDelegate.spacing || color != oldDelegate.color;

}
