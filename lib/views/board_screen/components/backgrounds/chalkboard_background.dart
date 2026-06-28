// ignore_for_file: cascade_invocations

import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';

class ChalkboardBackground extends StatelessWidget {

  final Color boardColor;
  final Widget? child;

  const ChalkboardBackground({
    super.key,
    required this.boardColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChalkboardPainter(boardColor: boardColor),
      child: child,
    );
  }

}

class _ChalkboardPainter extends CustomPainter {

  // Fixed seed so the smudges are deterministic. The Random is created *inside*
  // paint() (not stored as a field) so every repaint replays the exact same
  // sequence — otherwise a shared Random advances per paint and the smudges
  // shift around on each rebuild.
  static const int _seed = 42;

  final Color boardColor;

  _ChalkboardPainter({required this.boardColor});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(_seed);
    final paint = Paint();

    // Basic color
    paint.color = boardColor;
    canvas.drawRect(Offset.zero & size, paint);

    // Smudges
    for (int i = 0; i < 25; i++) {
      final path = Path();
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;

      path.moveTo(startX, startY);

      for (int j = 0; j < 5; j++) {
        path.quadraticBezierTo(
          startX + random.nextDouble() * 200 - 100,
          startY + random.nextDouble() * 200 - 100,
          startX + random.nextDouble() * 200 - 100,
          startY + random.nextDouble() * 200 - 100,
        );
      }

      paint
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = random.nextDouble() * 10 + 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ChalkboardPainter oldDelegate) => boardColor != oldDelegate.boardColor;

}
