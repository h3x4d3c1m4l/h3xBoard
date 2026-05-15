import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Renders a selection indicator (dashed border + action buttons) for a single
// selected widget. Must be placed inside the FittedBox canvas Stack wrapped in
// Positioned.fill so its children use the same 1920×1080 canvas coordinates as
// ManipulableBoardWidget.
//
// All visual sizes are multiplied by boardPixelRatio so they appear at host/OS
// pixel scale after the FittedBox scales them back down.
class WidgetSelectionOverlay extends StatelessWidget {

  final BoardWidget boardWidget;
  final double boardPixelRatio;
  final VoidCallback onDelete;
  final VoidCallback onSettings;

  const WidgetSelectionOverlay({
    super.key,
    required this.boardWidget,
    required this.boardPixelRatio,
    required this.onDelete,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final size = naturalSizeFor(boardWidget.type);
    final scaledW = size.width * boardWidget.scale;
    final scaledH = size.height * boardWidget.scale;
    final r = boardWidget.rotation;
    final ratio = boardPixelRatio;

    final borderMargin = 8.0 * ratio;
    final btnBarCanvasH = 64.0 * ratio;
    final gapCanvas = 6.0 * ratio;
    final btnBarCanvasW = 200.0 * ratio;

    final rotBboxHalfH =
        (scaledH / 2 + borderMargin) * math.cos(r).abs() +
        (scaledW / 2 + borderMargin) * math.sin(r).abs();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Dashed border at the same position/rotation as ManipulableBoardWidget.
        // IgnorePointer lets touch events fall through to lower layers.
        Positioned(
          left: boardWidget.x - scaledW / 2 - borderMargin,
          top: boardWidget.y - scaledH / 2 - borderMargin,
          width: scaledW + borderMargin * 2,
          height: scaledH + borderMargin * 2,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: r,
              alignment: Alignment.center,
              child: CustomPaint(painter: _DashedBorderPainter(ratio)),
            ),
          ),
        ),
        // Button bar centred above the widget's rotated visual top.
        Positioned(
          left: boardWidget.x - btnBarCanvasW / 2,
          top: boardWidget.y - rotBboxHalfH - gapCanvas - btnBarCanvasH,
          width: btnBarCanvasW,
          height: btnBarCanvasH,
          child: Center(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              // Transform.scale counter-acts the FittedBox downscale so the
              // buttons appear at their natural host/OS pixel size.
              child: Transform.scale(
                scale: ratio,
                child: _ActionButtonBar(onDelete: onDelete, onSettings: onSettings),
              ),
            ),
          ),
        ),
      ],
    );
  }

}

class _ActionButtonBar extends StatelessWidget {

  final VoidCallback onDelete;
  final VoidCallback onSettings;

  const _ActionButtonBar({required this.onDelete, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Center(
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Button(
                onPressed: onSettings,
                style: ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsetsDirectional.all(12))),
                child: const Icon(LucideIcons.settings, size: 32),
              ),
              const SizedBox(width: 4),
              Button(
                onPressed: onDelete,
                style: ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsetsDirectional.all(12))),
                child: const Icon(LucideIcons.trash2, size: 32, color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _DashedBorderPainter extends CustomPainter {

  final double boardPixelRatio;

  const _DashedBorderPainter(this.boardPixelRatio);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 1.5 * boardPixelRatio
      ..style = PaintingStyle.stroke;

    final dashLen = 6.0 * boardPixelRatio;
    final gapLen = 4.0 * boardPixelRatio;
    final radius = Radius.circular(4 * boardPixelRatio);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final path = Path()..addRRect(rrect);

    final metric = path.computeMetrics().first;
    double distance = 0;
    while (distance < metric.length) {
      final end = math.min(distance + dashLen, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.boardPixelRatio != boardPixelRatio;

}
