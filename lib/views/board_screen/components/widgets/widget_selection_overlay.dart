import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Callback type: each widget type returns its own list of settings menu items.
typedef WidgetSettingsBuilder = List<MenuFlyoutItemBase> Function(BuildContext context);

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
  final WidgetSettingsBuilder settingsBuilder;

  const WidgetSelectionOverlay({
    super.key,
    required this.boardWidget,
    required this.boardPixelRatio,
    required this.onDelete,
    required this.settingsBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final size = naturalSizeFor(boardWidget.config);
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
                child: _ActionButtonBar(onDelete: onDelete, settingsBuilder: settingsBuilder),
              ),
            ),
          ),
        ),
      ],
    );
  }

}

class _ActionButtonBar extends StatefulWidget {

  final VoidCallback onDelete;
  final WidgetSettingsBuilder settingsBuilder;

  const _ActionButtonBar({required this.onDelete, required this.settingsBuilder});

  @override
  State<_ActionButtonBar> createState() => _ActionButtonBarState();

}

class _ActionButtonBarState extends State<_ActionButtonBar> {

  final FlyoutController _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _openSettings() {
    _flyoutController.showFlyout(
      builder: (context) => MenuFlyout(
        itemMargin: const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 4),
        items: widget.settingsBuilder(context),
      ),
      placementMode: FlyoutPlacementMode.topCenter,
      additionalOffset: 8,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ButtonTheme.merge(
              data: ButtonThemeData(
                defaultButtonStyle: ButtonStyle(
                  shape: WidgetStateProperty.resolveWith(
                    (states) => _pillShape(ButtonThemeData.shapeBorder(context, states), isLeft: true),
                  ),
                ),
              ),
              child: FlyoutTarget(
                controller: _flyoutController,
                child: Button(
                  onPressed: _openSettings,
                  style: ButtonStyle(
                    padding: const WidgetStatePropertyAll(EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 16)),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.isPressed) return const Color(0xFFB8B8B8);
                      if (states.isHovered) return const Color(0xFFD8D8D8);
                      return Colors.white;
                    }),
                  ),
                  child: const Icon(LucideIcons.settings),
                ),
              ),
            ),
            ButtonTheme.merge(
              data: ButtonThemeData(
                defaultButtonStyle: ButtonStyle(
                  shape: WidgetStateProperty.resolveWith(
                    (states) => _pillShape(ButtonThemeData.shapeBorder(context, states), isLeft: false),
                  ),
                ),
              ),
              child: Button(
                onPressed: widget.onDelete,
                style: ButtonStyle(
                  padding: const WidgetStatePropertyAll(EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 16)),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.isPressed) return const Color(0xFFE0E0E0);
                    if (states.isHovered) return const Color(0xFFF0F0F0);
                    return Colors.white;
                  }),
                ),
                child: const Icon(LucideIcons.trash2, color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static ShapeBorder _pillShape(ShapeBorder border, {required bool isLeft}) {
    const nearRadius = Radius.circular(16);
    if (border is RoundedRectangleBorder) {
      final old = border.borderRadius as BorderRadius;
      return border.copyWith(borderRadius: old.copyWith(
        topLeft: isLeft ? nearRadius : Radius.zero,
        bottomLeft: isLeft ? nearRadius : Radius.zero,
        topRight: isLeft ? Radius.zero : nearRadius,
        bottomRight: isLeft ? Radius.zero : nearRadius,
      ));
    } else if (border is RoundedRectangleGradientBorder) {
      final old = border.borderRadius as BorderRadius;
      return border.copyWith(
        gradient: border.gradient,
        borderRadius: old.copyWith(
          topLeft: isLeft ? nearRadius : Radius.zero,
          bottomLeft: isLeft ? nearRadius : Radius.zero,
          topRight: isLeft ? Radius.zero : nearRadius,
          bottomRight: isLeft ? Radius.zero : nearRadius,
        ),
        width: border.width,
        strokeAlign: border.strokeAlign,
      );
    }
    return border;
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
