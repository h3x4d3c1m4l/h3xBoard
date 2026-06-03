import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Visual constants (in OS pixels; multiplied by boardPixelRatio to get canvas units).
// Kept package-visible (no leading underscore) so board.dart can mirror the hit-test math.
const double kOverlayBorderMargin = 8.0;
const double kOverlayStemLength = 32.0;
const double kOverlayHandleRadius = 8.0;
const double kOverlayCornerSize = 7.0; // half-side of corner square handle

// Computes the canvas-space position of the rotation handle center for a given widget.
// Exposed so board.dart can mirror the math in _isPointOnAnyHandle.
Offset rotationHandleCenter(BoardWidget bw, double ratio) {
  final size = naturalSizeFor(bw.config);
  final scaledH = size.height * bw.scale;
  final borderMargin = kOverlayBorderMargin * ratio;
  final stemLength = kOverlayStemLength * ratio;
  final handleRadius = kOverlayHandleRadius * ratio;
  final localDy = -(scaledH / 2 + borderMargin + stemLength + handleRadius);
  return Offset(
    bw.x + (-math.sin(bw.rotation) * localDy),
    bw.y + (math.cos(bw.rotation) * localDy),
  );
}

// Computes the four corner handle positions in canvas space.
// Exposed so board.dart can mirror the math in _isPointOnAnyHandle.
List<Offset> cornerHandlePositions(BoardWidget bw, double ratio) {
  final size = naturalSizeFor(bw.config);
  final scaledW = size.width * bw.scale;
  final scaledH = size.height * bw.scale;
  final borderMargin = kOverlayBorderMargin * ratio;
  final hw = scaledW / 2 + borderMargin;
  final hh = scaledH / 2 + borderMargin;
  final cosR = math.cos(bw.rotation);
  final sinR = math.sin(bw.rotation);
  Offset rot(Offset local) => Offset(
    local.dx * cosR - local.dy * sinR,
    local.dx * sinR + local.dy * cosR,
  );
  final center = Offset(bw.x, bw.y);
  return [
    center + rot(Offset(-hw, -hh)),
    center + rot(Offset(hw, -hh)),
    center + rot(Offset(hw, hh)),
    center + rot(Offset(-hw, hh)),
  ];
}

// Renders a selection indicator (dashed border + rotate/scale handles + action buttons)
// for a single selected widget. Must be placed inside the FittedBox canvas Stack
// wrapped in Positioned.fill so its children use the same 1920×1080 canvas coordinates.
//
// All visual sizes are multiplied by boardPixelRatio so they appear at host/OS pixel
// scale after the FittedBox scales them back down.
class WidgetSelectionOverlay extends StatefulWidget {

  final BoardWidget boardWidget;
  final double boardPixelRatio;
  final VoidCallback onDelete;
  final WidgetSettingsBuilder settingsBuilder;
  final VoidCallback onHandleTransformStart;
  final void Function(double rotation, double scale) onHandleTransformUpdate;
  final VoidCallback onHandleTransformEnd;

  const WidgetSelectionOverlay({
    super.key,
    required this.boardWidget,
    required this.boardPixelRatio,
    required this.onDelete,
    required this.settingsBuilder,
    required this.onHandleTransformStart,
    required this.onHandleTransformUpdate,
    required this.onHandleTransformEnd,
  });

  @override
  State<WidgetSelectionOverlay> createState() => _WidgetSelectionOverlayState();

}

class _WidgetSelectionOverlayState extends State<WidgetSelectionOverlay> {

  // GlobalKey on the full-canvas Stack so we can convert global screen coords to
  // canvas coords via RenderBox.globalToLocal.
  final _stackKey = GlobalKey();

  // Which handle is currently being dragged: 'rotate' | 'corner_tl' | 'corner_tr' | 'corner_br' | 'corner_bl'
  String? _activeDragHandle;
  Offset _dragStartCenter = Offset.zero;
  double _dragStartRotation = 0.0;
  double _dragStartScale = 1.0;
  // Angle from widget center to pointer at drag start (for rotation handle).
  double _dragStartHandleAngle = 0.0;
  // Distance from widget center to pointer at drag start (for corner handles).
  double _dragStartDistance = 0.0;

  // Converts a global screen position (from PointerEvent.position) to canvas-space
  // coordinates using the full-canvas Stack's RenderBox transform.
  Offset _toCanvas(Offset globalPos) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.globalToLocal(globalPos);
  }

  // ---- Rotation handle ----

  void _onRotateDown(PointerDownEvent e) {
    final bw = widget.boardWidget;
    _activeDragHandle = 'rotate';
    _dragStartCenter = Offset(bw.x, bw.y);
    _dragStartRotation = bw.rotation;
    final p = _toCanvas(e.position);
    _dragStartHandleAngle = math.atan2(p.dy - _dragStartCenter.dy, p.dx - _dragStartCenter.dx);
    widget.onHandleTransformStart();
  }

  void _onRotateMove(PointerMoveEvent e) {
    if (_activeDragHandle != 'rotate') return;
    final p = _toCanvas(e.position);
    final angle = math.atan2(p.dy - _dragStartCenter.dy, p.dx - _dragStartCenter.dx);
    widget.onHandleTransformUpdate(
      _dragStartRotation + (angle - _dragStartHandleAngle),
      widget.boardWidget.scale,
    );
  }

  void _onRotateUp(PointerUpEvent e) {
    if (_activeDragHandle != 'rotate') return;
    _activeDragHandle = null;
    widget.onHandleTransformEnd();
  }

  void _onRotateCancel(PointerCancelEvent e) {
    if (_activeDragHandle != 'rotate') return;
    _activeDragHandle = null;
    widget.onHandleTransformEnd();
  }

  // ---- Corner scale handles ----

  void _onCornerDown(String corner, PointerDownEvent e) {
    final bw = widget.boardWidget;
    _activeDragHandle = corner;
    _dragStartCenter = Offset(bw.x, bw.y);
    _dragStartRotation = bw.rotation;
    _dragStartScale = bw.scale;
    final p = _toCanvas(e.position);
    _dragStartDistance = (p - _dragStartCenter).distance;
    widget.onHandleTransformStart();
  }

  void _onCornerMove(PointerMoveEvent e) {
    if (_activeDragHandle == null || _activeDragHandle == 'rotate') return;
    if (_dragStartDistance < 1.0) return;
    final p = _toCanvas(e.position);
    final dist = (p - _dragStartCenter).distance;
    final newScale = (_dragStartScale * dist / _dragStartDistance).clamp(0.2, 5.0);
    widget.onHandleTransformUpdate(_dragStartRotation, newScale);
  }

  void _onCornerUp(PointerUpEvent e) {
    if (_activeDragHandle == null || _activeDragHandle == 'rotate') return;
    _activeDragHandle = null;
    widget.onHandleTransformEnd();
  }

  void _onCornerCancel(PointerCancelEvent e) {
    if (_activeDragHandle == null || _activeDragHandle == 'rotate') return;
    _activeDragHandle = null;
    widget.onHandleTransformEnd();
  }

  @override
  Widget build(BuildContext context) {
    final bw = widget.boardWidget;
    final size = naturalSizeFor(bw.config);
    final scaledW = size.width * bw.scale;
    final scaledH = size.height * bw.scale;
    final r = bw.rotation;
    final ratio = widget.boardPixelRatio;
    final cosR = math.cos(r);
    final sinR = math.sin(r);

    final borderMargin = kOverlayBorderMargin * ratio;
    final btnBarCanvasH = 64.0 * ratio;
    final gapCanvas = 6.0 * ratio;
    final btnBarCanvasW = 200.0 * ratio;
    final stemLength = kOverlayStemLength * ratio;
    final handleRadius = kOverlayHandleRadius * ratio;
    final cornerSize = kOverlayCornerSize * ratio;

    // Rotation handle: positioned in the widget's local Y-axis (straight above the top edge).
    final handleCenter = rotationHandleCenter(bw, ratio);

    // Stem: from the top-center of the dashed border to the rotation handle center.
    final stemStartDy = -(scaledH / 2 + borderMargin);
    final stemStart = Offset(bw.x + (-sinR * stemStartDy), bw.y + (cosR * stemStartDy));

    // Corner handles.
    final corners = cornerHandlePositions(bw, ratio);
    final cornerKeys = ['corner_tl', 'corner_tr', 'corner_br', 'corner_bl'];

    // Button bar: push above the rotation handle when it extends farther than the border AABB.
    final rotBboxHalfH =
        (scaledH / 2 + borderMargin) * cosR.abs() + (scaledW / 2 + borderMargin) * sinR.abs();
    final handleArmTop = scaledH / 2 + borderMargin + stemLength + 2 * handleRadius;
    final effectiveHalfH = math.max(rotBboxHalfH, handleArmTop * cosR.abs());

    return Stack(
      key: _stackKey,
      clipBehavior: Clip.none,
      children: [
        // Dashed border at the same position/rotation as ManipulableBoardWidget.
        // IgnorePointer lets touch events fall through to lower layers.
        Positioned(
          left: bw.x - scaledW / 2 - borderMargin,
          top: bw.y - scaledH / 2 - borderMargin,
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
        // Stem line from dashed border top to rotation handle center.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _StemPainter(from: stemStart, to: handleCenter, ratio: ratio)),
          ),
        ),
        // Rotation handle circle.
        Positioned(
          left: handleCenter.dx - handleRadius,
          top: handleCenter.dy - handleRadius,
          width: handleRadius * 2,
          height: handleRadius * 2,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onRotateDown,
              onPointerMove: _onRotateMove,
              onPointerUp: _onRotateUp,
              onPointerCancel: _onRotateCancel,
              child: CustomPaint(painter: _HandleCirclePainter(ratio)),
            ),
          ),
        ),
        // Corner scale handles.
        for (var i = 0; i < corners.length; i++)
          Positioned(
            left: corners[i].dx - cornerSize,
            top: corners[i].dy - cornerSize,
            width: cornerSize * 2,
            height: cornerSize * 2,
            child: MouseRegion(
              cursor: i == 0 || i == 2
                  ? SystemMouseCursors.resizeUpLeftDownRight
                  : SystemMouseCursors.resizeUpRightDownLeft,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _onCornerDown(cornerKeys[i], e),
                onPointerMove: _onCornerMove,
                onPointerUp: _onCornerUp,
                onPointerCancel: _onCornerCancel,
                child: CustomPaint(painter: _HandleSquarePainter(ratio)),
              ),
            ),
          ),
        // Button bar centred above the widget's rotated visual top (or rotation handle, whichever is higher).
        Positioned(
          left: bw.x - btnBarCanvasW / 2,
          top: bw.y - effectiveHalfH - gapCanvas - btnBarCanvasH,
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
                child: _ActionButtonBar(onDelete: widget.onDelete, settingsBuilder: widget.settingsBuilder),
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

class _StemPainter extends CustomPainter {

  final Offset from;
  final Offset to;
  final double ratio;

  const _StemPainter({required this.from, required this.to, required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..strokeWidth = 1.5 * ratio
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_StemPainter old) =>
      old.from != from || old.to != to || old.ratio != ratio;

}

class _HandleCirclePainter extends CustomPainter {

  final double ratio;

  const _HandleCirclePainter(this.ratio);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas
      ..drawCircle(center, r, Paint()..color = Colors.white)
      ..drawCircle(
        center,
        r,
        Paint()
          ..color = const Color(0xFF3B82F6)
          ..strokeWidth = 1.5 * ratio
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(_HandleCirclePainter old) => old.ratio != ratio;

}

class _HandleSquarePainter extends CustomPainter {

  final double ratio;

  const _HandleSquarePainter(this.ratio);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas
      ..drawRect(rect, Paint()..color = Colors.white)
      ..drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF3B82F6)
          ..strokeWidth = 1.5 * ratio
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(_HandleSquarePainter old) => old.ratio != ratio;

}
