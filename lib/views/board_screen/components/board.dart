import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/background_lines.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/chalkboard_background.dart';
import 'package:h3xboard/views/board_screen/components/widgets/clock_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';

class Board extends StatefulWidget {
  final DrawingController drawingController;
  final BoardScreenViewModel viewModel;

  const Board({super.key, required this.drawingController, required this.viewModel});

  @override
  State<Board> createState() => _BoardState();
}

class _BoardState extends State<Board> {
  Offset? _pointerPosition;
  double? _eraseStrokeWidth;

  // Widget manipulation state. All coordinates are in the 1920×1080 canvas
  // space, which equals localFocalPoint of the full-canvas GestureDetector.
  String? _activeWidgetId;
  double _currentX = 0;
  double _currentY = 0;
  double _gestureStartRotation = 0;
  double _gestureStartScale = 1;
  Offset? _lastFocalPoint;

  // ScaleGestureRecognizer only fires onScaleStart after the touch-slop
  // threshold is exceeded, by which point the finger may have moved outside
  // the widget. We record the true PointerDown position via a Listener (which
  // fires immediately, before any slop) so that widget hit-testing uses the
  // original touch point rather than the post-slop focal point.
  int? _firstPointerId;
  Offset? _initialTouchPosition;

  @override
  void initState() {
    widget.drawingController.drawConfig.addListener(_onDrawConfigChanged);
    super.initState();
  }

  void _onDrawConfigChanged() {
    setState(() {
      _eraseStrokeWidth = widget.drawingController.eraserContent?.paint.strokeWidth;
    });
  }

  Widget _buildWidgetContent(BoardWidgetType type) => switch (type) {
        BoardWidgetType.clock => const ClockWidget(),
      };

  // Exact hit test for a rotated rectangle: inverse-rotate the canvas point
  // into the widget's local frame, then do an axis-aligned bounds check.
  bool _isPointOnWidget(Offset canvasPoint, BoardWidget bw) {
    final size = naturalSizeFor(bw.type);
    final dx = canvasPoint.dx - bw.x;
    final dy = canvasPoint.dy - bw.y;
    final cosA = math.cos(-bw.rotation);
    final sinA = math.sin(-bw.rotation);
    final localX = dx * cosA - dy * sinA;
    final localY = dx * sinA + dy * cosA;
    return localX.abs() <= size.width * bw.scale / 2 && localY.abs() <= size.height * bw.scale / 2;
  }

  void _onPointerDown(PointerDownEvent event) {
    // Only capture the very first pointer of a new gesture. Subsequent fingers
    // must not overwrite the initial position used for widget detection.
    if (_firstPointerId == null) {
      _firstPointerId = event.pointer;
      _initialTouchPosition = event.localPosition;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _firstPointerId) {
      _firstPointerId = null;
      _initialTouchPosition = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _firstPointerId) {
      _firstPointerId = null;
      _initialTouchPosition = null;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;

    if (_activeWidgetId != null) {
      // Finger count changed mid-gesture: keep tracking the same widget but
      // reset rotation/scale baselines to the current accumulated values.
      final bw = widget.viewModel.boardWidgets.firstWhere((b) => b.id == _activeWidgetId);
      _gestureStartRotation = bw.rotation;
      _gestureStartScale = bw.scale;
      return;
    }

    // Use the Listener-recorded initial touch position (pre-slop) rather than
    // details.localFocalPoint (post-slop) for accurate widget hit-testing.
    final checkPoint = _initialTouchPosition ?? details.localFocalPoint;
    for (final bw in widget.viewModel.boardWidgets) {
      if (_isPointOnWidget(checkPoint, bw)) {
        setState(() => _activeWidgetId = bw.id);
        _currentX = bw.x;
        _currentY = bw.y;
        _gestureStartRotation = bw.rotation;
        _gestureStartScale = bw.scale;
        return;
      }
    }
    _activeWidgetId = null;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_activeWidgetId == null) return;
    final delta = details.localFocalPoint - _lastFocalPoint!;
    _lastFocalPoint = details.localFocalPoint;
    _currentX += delta.dx;
    _currentY += delta.dy;
    final newRotation = _gestureStartRotation + details.rotation;
    final newScale = (_gestureStartScale * details.scale).clamp(0.2, 5.0);
    widget.viewModel.updateBoardWidget(_activeWidgetId!, _currentX, _currentY, newRotation, newScale);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // pointerCount > 0 means fingers are still active: this end was triggered by
    // a finger-count change mid-gesture (ScaleGestureRecognizer calls onEnd then
    // defers onStart until the next move). Keep _activeWidgetId so the upcoming
    // onScaleStart can enter the mid-gesture branch instead of re-detecting.
    if (details.pointerCount == 0) {
      setState(() => _activeWidgetId = null);
      _firstPointerId = null;
      _initialTouchPosition = null;
    }
    _lastFocalPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      final board = widget.viewModel.board;
      return Container(
        decoration: BoxDecoration(
          border: board.backgroundColor == Colors.white
              ? BoxBorder.all(width: 1, color: Colors.black12, strokeAlign: BorderSide.strokeAlignOutside)
              : null,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: FittedBox(
          child: SizedBox(
            width: 1920,
            height: 1080,
            child: Stack(
              children: [
                IgnorePointer(
                  ignoring: _activeWidgetId != null,
                  child: DrawingBoard(
                    controller: widget.drawingController,
                    background: Observer(builder: (_) {
                      final board = widget.viewModel.board;
                      Widget box = BackgroundLines(
                        pattern: board.linePattern,
                        spacing: board.lineSpacing,
                        color: board.lineColor,
                        child: SizedBox(width: 1920, height: 1080),
                      );
                      return board.isChalkboard
                          ? ChalkboardBackground(
                              boardColor: board.backgroundColor,
                              child: box,
                            )
                          : ColoredBox(color: board.backgroundColor, child: box);
                    }),
                    onPointerDown: (pde) => setState(() => _pointerPosition = pde.localPosition),
                    onPointerMove: (pme) => setState(() => _pointerPosition = pme.localPosition),
                    onPointerUp: (pue) => setState(() => _pointerPosition = null),
                    boardPanEnabled: false,
                    boardScaleEnabled: false,
                  ),
                ),
                for (final bw in widget.viewModel.boardWidgets)
                  ManipulableBoardWidget(
                    key: ValueKey(bw.id),
                    boardWidget: bw,
                    child: _buildWidgetContent(bw.type),
                  ),
                if (_eraseStrokeWidth != null)
                  Positioned(
                    left: _pointerPosition!.dx - (_eraseStrokeWidth! / 2),
                    top: _pointerPosition!.dy - (_eraseStrokeWidth! / 2),
                    width: _eraseStrokeWidth,
                    height: _eraseStrokeWidth,
                    child: Container(
                      decoration:
                          BoxDecoration(border: BoxBorder.all(), shape: BoxShape.circle, color: Colors.white),
                    ),
                  ),
                // Full-canvas gesture + pointer layer for widget manipulation.
                // Listener fires on PointerDown immediately (no slop) so we
                // can record the true initial touch for widget hit-testing.
                // GestureDetector is translucent so DrawingBoard's Listener
                // still fires for drawing strokes.
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onPointerDown,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onScaleEnd: _onScaleEnd,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    widget.drawingController.drawConfig.removeListener(_onDrawConfigChanged);
    super.dispose();
  }
}
