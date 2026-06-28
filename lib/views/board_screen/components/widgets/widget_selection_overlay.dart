import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';

// Visual constants (in OS pixels; multiplied by boardPixelRatio to get canvas units).
// Kept package-visible (no leading underscore) so board.dart can mirror the hit-test math.
const double kOverlayBorderMargin = 8.0;
const double kOverlayStemLength = 32.0;
const double kOverlayHandleRadius = 8.0;
const double kOverlayCornerSize = 7.0; // half-side of corner square handle
const double kOverlayHandleTouch = 44.0; // touch target size for handles (finger-friendly)

// Picks the best direction for the rotation handle so it stays on-canvas.
// Tests all 4 widget-local axis directions and picks the one whose handle circle
// sits furthest inside the 1920×1080 canvas bounds.
// Returns canvas-space positions for both the stem start (on the border edge) and
// the handle center (tip of the stem arm).
({Offset stemStart, Offset handleCenter}) computeRotationHandle(BoardWidget bw, double ratio) {
  final size = naturalSizeFor(bw.config);
  final scaledW = size.width * bw.scale;
  final scaledH = size.height * bw.scale;
  final borderMargin = kOverlayBorderMargin * ratio;
  final stemLength = kOverlayStemLength * ratio;
  final handleRadius = kOverlayHandleRadius * ratio;
  final cosR = math.cos(bw.rotation);
  final sinR = math.sin(bw.rotation);

  // Candidate directions in widget-local space: up, down, right, left.
  // Each is (stemStartLocal, handleCenterLocal).
  final hH = scaledH / 2 + borderMargin;
  final hW = scaledW / 2 + borderMargin;
  final armH = hH + stemLength + handleRadius;
  final armW = hW + stemLength + handleRadius;
  final candidates = [
    (Offset(0, -hH), Offset(0, -armH)),
    (Offset(0,  hH), Offset(0,  armH)),
    (Offset( hW, 0), Offset( armW, 0)),
    (Offset(-hW, 0), Offset(-armW, 0)),
  ];

  // Rotate a widget-local vector to canvas space.
  Offset toCanvas(Offset local) => Offset(
    bw.x + local.dx * cosR - local.dy * sinR,
    bw.y + local.dx * sinR + local.dy * cosR,
  );

  // Higher score = handle circle sits further from all canvas edges.
  // Negative score means part of the circle is off-canvas.
  double score(Offset pos) => math.min(
    math.min(pos.dx - handleRadius, 1920 - pos.dx - handleRadius),
    math.min(pos.dy - handleRadius, 1080 - pos.dy - handleRadius),
  );

  var bestStem   = toCanvas(candidates[0].$1);
  var bestHandle = toCanvas(candidates[0].$2);
  var bestScore  = score(bestHandle);

  for (var i = 1; i < candidates.length; i++) {
    final stem   = toCanvas(candidates[i].$1);
    final handle = toCanvas(candidates[i].$2);
    final s      = score(handle);
    if (s > bestScore) {
      bestStem = stem; bestHandle = handle; bestScore = s;
    }
  }
  return (stemStart: bestStem, handleCenter: bestHandle);
}

// Convenience wrapper — returns just the handle center.
// board.dart uses this for hit-testing in _isPointOnAnyHandle.
Offset rotationHandleCenter(BoardWidget bw, double ratio) =>
    computeRotationHandle(bw, ratio).handleCenter;

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
  final VoidCallback onHandleTransformStart;
  final void Function(double rotation, double scale) onHandleTransformUpdate;
  final VoidCallback onHandleTransformEnd;

  const WidgetSelectionOverlay({
    super.key,
    required this.boardWidget,
    required this.boardPixelRatio,
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
    var newRotation = _dragStartRotation + (angle - _dragStartHandleAngle);
    // Hold Shift to snap rotation to 15° increments.
    if (HardwareKeyboard.instance.isShiftPressed) {
      const step = math.pi / 12;
      newRotation = (newRotation / step).round() * step;
    }
    widget.onHandleTransformUpdate(newRotation, widget.boardWidget.scale);
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

    final borderMargin = kOverlayBorderMargin * ratio;
    final handleRadius = kOverlayHandleRadius * ratio;
    final cornerSize = kOverlayCornerSize * ratio;
    final touch = kOverlayHandleTouch * ratio;

    // Rotation handle: pick the direction (up/down/left/right) that keeps the handle on-canvas.
    final placement = computeRotationHandle(bw, ratio);
    final stemStart = placement.stemStart;
    final handleCenter = placement.handleCenter;

    // Corner handles.
    final corners = cornerHandlePositions(bw, ratio);
    final cornerKeys = ['corner_tl', 'corner_tr', 'corner_br', 'corner_bl'];

    return Stack(
      key: _stackKey,
      clipBehavior: Clip.none,
      children: [
        // Continuous solid border at the same position/rotation as ManipulableBoardWidget.
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
              child: CustomPaint(painter: _SolidBorderPainter(ratio)),
            ),
          ),
        ),
        // Stem line from border top to rotation handle center.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _StemPainter(from: stemStart, to: handleCenter, ratio: ratio)),
          ),
        ),
        // Rotation handle: small circle glyph inside a finger-friendly touch target.
        Positioned(
          left: handleCenter.dx - touch / 2,
          top: handleCenter.dy - touch / 2,
          width: touch,
          height: touch,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onRotateDown,
              onPointerMove: _onRotateMove,
              onPointerUp: _onRotateUp,
              onPointerCancel: _onRotateCancel,
              child: Center(
                child: SizedBox(
                  width: handleRadius * 2,
                  height: handleRadius * 2,
                  child: CustomPaint(painter: _HandleCirclePainter(ratio)),
                ),
              ),
            ),
          ),
        ),
        // Corner scale handles: small square glyph inside a finger-friendly touch target.
        // Hidden for scale-locked widgets (e.g. grid-matched rulers) — they can't resize.
        if (!bw.isScaleLocked)
          for (var i = 0; i < corners.length; i++)
          Positioned(
            left: corners[i].dx - touch / 2,
            top: corners[i].dy - touch / 2,
            width: touch,
            height: touch,
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
                child: Center(
                  child: SizedBox(
                    width: cornerSize * 2,
                    height: cornerSize * 2,
                    child: CustomPaint(painter: _HandleSquarePainter(ratio)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

}

class _SolidBorderPainter extends CustomPainter {

  final double boardPixelRatio;

  const _SolidBorderPainter(this.boardPixelRatio);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 1.5 * boardPixelRatio
      ..style = PaintingStyle.stroke;

    final radius = Radius.circular(4 * boardPixelRatio);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
  }

  @override
  bool shouldRepaint(_SolidBorderPainter old) => old.boardPixelRatio != boardPixelRatio;

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
