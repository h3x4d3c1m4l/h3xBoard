import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent, PointerSignalEvent, kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/drawing_tools.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/background_lines.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/chalkboard_background.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/widget_selection_overlay.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class Board extends StatefulWidget {

  final DrawingController drawingController;
  final BoardScreenViewModel viewModel;
  final void Function(String id) onDeleteWidget;
  final void Function(String id, BoardWidgetConfig config) onWidgetConfigChanged;
  final void Function(String id) onWidgetTransformStart;
  final void Function(String id) onWidgetTransformEnd;
  final VoidCallback onDrawingStrokeStart;
  final VoidCallback onDrawingStrokeEnd;
  final void Function(String id) onMoveWidgetToTop;
  final void Function(String id) onMoveWidgetUp;
  final void Function(String id) onMoveWidgetDown;
  final void Function(String id) onMoveWidgetToBottom;
  final VoidCallback onRestoreDrawingTool;

  const Board({
    super.key,
    required this.drawingController,
    required this.viewModel,
    required this.onDeleteWidget,
    required this.onWidgetConfigChanged,
    required this.onWidgetTransformStart,
    required this.onWidgetTransformEnd,
    required this.onDrawingStrokeStart,
    required this.onDrawingStrokeEnd,
    required this.onMoveWidgetToTop,
    required this.onMoveWidgetUp,
    required this.onMoveWidgetDown,
    required this.onMoveWidgetToBottom,
    required this.onRestoreDrawingTool,
  });

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

  // Distinguishes a tap (select intent) from a drag (move intent).
  // Set to true as soon as cumulative movement in a gesture exceeds 3 canvas px.
  bool _gestureMovedSignificantly = false;

  // True when the first pointer of the current gesture landed on empty canvas
  // (no widget hit). Used by _onPointerUp to deselect without waiting for scale.
  bool _tapCandidateOnEmptySpace = false;

  // When a widget is selected, IgnorePointer blocks DrawingBoard for the whole
  // gesture (the MobX Observer won't rebuild until the next frame). If the user
  // draws on empty canvas while something is selected, we manually forward the
  // draw events through the outer Listener so the first stroke is not lost.
  bool _drawingStartedManually = false;

  // Prevents auto-select from firing on every update frame during a drag.
  bool _autoSelectedForDrag = false;

  // Context menu state: a zero-size FlyoutTarget is placed at the right-click
  // canvas position so the flyout appears exactly at the cursor.
  final FlyoutController _contextMenuController = FlyoutController();
  Offset? _contextMenuCanvasPos;
  WidgetSettingsBuilder? _contextMenuBuilder;

  // True while a selection-overlay handle (rotate / corner scale) is being dragged.
  // Prevents the board's ScaleGestureRecognizer from interfering with the handle drag.
  bool _handleDragActive = false;

  // Debounces scroll-to-scale: groups rapid scroll ticks into a single undo history entry.
  Timer? _scrollEndTimer;

  @override
  void initState() {
    widget.drawingController.drawConfig.addListener(_onDrawConfigChanged);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    super.initState();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      widget.viewModel.clearSelection();
      return true;
    }
    return false;
  }

  void _onDrawConfigChanged() {
    setState(() {
      _eraseStrokeWidth = widget.drawingController.eraserContent?.paint.strokeWidth;
    });
  }

  Widget _buildWidgetContent(BoardWidget bw) => descriptorFor(bw.config).buildWidget(bw.config);

  List<MenuFlyoutItemBase> _buildSettingsItems(BuildContext context, BoardWidget bw) {
    final typeItems = descriptorFor(bw.config).settingsMenuItems(
      context,
      bw.config,
      (newConfig) => widget.onWidgetConfigChanged(bw.id, newConfig),
    );
    final currentIndex = widget.viewModel.boardWidgets.indexWhere((w) => w.id == bw.id);
    final maxIndex = widget.viewModel.boardWidgets.length - 1;
    final isTop = currentIndex == maxIndex;
    final isBottom = currentIndex == 0;
    return [
      ...typeItems,
      if (typeItems.isNotEmpty) const MenuFlyoutSeparator(),
      MenuFlyoutSubItem(
        leading: const Icon(LucideIcons.layers),
        text: Text(context.localizations.layerMenu_title),
        items: (_) => [
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.chevronsUp),
            text: Text(context.localizations.layerMenu_bringToFront),
            onPressed: isTop ? null : () => widget.onMoveWidgetToTop(bw.id),
          ),
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.chevronUp),
            text: Text(context.localizations.layerMenu_bringForward),
            onPressed: isTop ? null : () => widget.onMoveWidgetUp(bw.id),
          ),
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.chevronDown),
            text: Text(context.localizations.layerMenu_sendBackward),
            onPressed: isBottom ? null : () => widget.onMoveWidgetDown(bw.id),
          ),
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.chevronsDown),
            text: Text(context.localizations.layerMenu_sendToBack),
            onPressed: isBottom ? null : () => widget.onMoveWidgetToBottom(bw.id),
          ),
        ],
      ),
    ];
  }

  // Returns true if canvasPoint is inside the action button bar of any currently
  // selected widget's overlay. Must mirror the position math in WidgetSelectionOverlay
  // so that _onPointerDown can skip clearSelection() for button-bar taps, preventing
  // the overlay from being disposed before the button's tap recognizer fires.
  bool _isPointOnAnyButtonBar(Offset canvasPoint) {
    final ratio = widget.viewModel.boardPixelRatio;
    const borderMargin = 8.0;
    const btnBarH = 64.0;
    const btnBarW = 200.0;
    const gap = 6.0;
    for (final bw in widget.viewModel.boardWidgets) {
      if (!widget.viewModel.selectedWidgetIds.contains(bw.id)) continue;
      final size = naturalSizeFor(bw.config);
      final scaledW = size.width * bw.scale;
      final scaledH = size.height * bw.scale;
      final r = bw.rotation;
      final cosR = math.cos(r).abs();
      final sinR = math.sin(r).abs();
      final borderMarginCanvas = borderMargin * ratio;
      final rotBboxHalfH = (scaledH / 2 + borderMarginCanvas) * cosR +
          (scaledW / 2 + borderMarginCanvas) * sinR;
      // Mirror the overlay's effectiveHalfH: push button bar above the rotation handle
      // when the handle arm extends further up than the border AABB.
      final stemLength = kOverlayStemLength * ratio;
      final handleRadius = kOverlayHandleRadius * ratio;
      final handleArmTop = scaledH / 2 + borderMarginCanvas + stemLength + 2 * handleRadius;
      final effectiveHalfH = math.max(rotBboxHalfH, handleArmTop * cosR);
      final left = bw.x - btnBarW * ratio / 2;
      final top = bw.y - effectiveHalfH - gap * ratio - btnBarH * ratio;
      if (canvasPoint.dx >= left &&
          canvasPoint.dx <= left + btnBarW * ratio &&
          canvasPoint.dy >= top &&
          canvasPoint.dy <= top + btnBarH * ratio) {
        return true;
      }
    }
    return false;
  }

  // Returns true if canvasPoint is within a handle (rotation circle or corner scale square)
  // of any currently selected widget. Mirrors the position math in WidgetSelectionOverlay
  // so that _onPointerDown can skip clearSelection() when the user clicks a handle.
  bool _isPointOnAnyHandle(Offset canvasPoint) {
    final ratio = widget.viewModel.boardPixelRatio;
    final handleRadius = kOverlayHandleRadius * ratio;
    final cornerSize = kOverlayCornerSize * ratio;
    for (final bw in widget.viewModel.boardWidgets) {
      if (!widget.viewModel.selectedWidgetIds.contains(bw.id)) continue;
      if ((canvasPoint - rotationHandleCenter(bw, ratio)).distance <= handleRadius * 2) return true;
      for (final pos in cornerHandlePositions(bw, ratio)) {
        if ((canvasPoint - pos).distance <= cornerSize * 2) return true;
      }
    }
    return false;
  }

  // Exact hit test for a rotated rectangle: inverse-rotate the canvas point
  // into the widget's local frame, then do an axis-aligned bounds check.
  bool _isPointOnWidget(Offset canvasPoint, BoardWidget bw) {
    final size = naturalSizeFor(bw.config);
    final dx = canvasPoint.dx - bw.x;
    final dy = canvasPoint.dy - bw.y;
    final cosA = math.cos(-bw.rotation);
    final sinA = math.sin(-bw.rotation);
    final localX = dx * cosA - dy * sinA;
    final localY = dx * sinA + dy * cosA;
    return localX.abs() <= size.width * bw.scale / 2 && localY.abs() <= size.height * bw.scale / 2;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kSecondaryMouseButton != 0) {
      for (final bw in widget.viewModel.boardWidgets.reversed) {
        if (_isPointOnWidget(event.localPosition, bw)) {
          widget.viewModel.selectWidget(bw.id);
          _contextMenuCanvasPos = event.localPosition;
          _contextMenuBuilder = (context) => _buildSettingsItems(context, bw);
          setState(() {});
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final builder = _contextMenuBuilder;
            if (builder == null) return;
            _contextMenuController.showFlyout(
              builder: (context) => MenuFlyout(
                itemMargin: const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 4),
                items: builder(context),
              ),
              placementMode: FlyoutPlacementMode.auto,
            );
          });
          return;
        }
      }
      return;
    }

    // Only capture the very first pointer of a new gesture. Subsequent fingers
    // must not overwrite the initial position used for widget detection.
    if (_firstPointerId == null) {
      _firstPointerId = event.pointer;
      _initialTouchPosition = event.localPosition;
      // Determine at pointer-down time (before any slop/gesture handling) whether
      // the touch landed on empty canvas. Used in _onPointerUp for deselection.
      // ScaleGestureRecognizer only fires after slop, so stationary taps never
      // reach _onScaleEnd — the Listener is more reliable for this case.
      _tapCandidateOnEmptySpace = !widget.viewModel.boardWidgets.any(
            (bw) => _isPointOnWidget(event.localPosition, bw),
          ) &&
          !_isPointOnAnyButtonBar(event.localPosition) &&
          !_isPointOnAnyHandle(event.localPosition);

      if (_tapCandidateOnEmptySpace) {
        final hadSelection = widget.viewModel.selectedWidgetIds.isNotEmpty;

        // When in pointer mode, restore the last drawing tool.
        if (widget.viewModel.drawingTools.activeTool == SelectableEditTool.pointer) {
          widget.onRestoreDrawingTool();
        } else if (hadSelection) {
          // Drawing tool already active but DrawingBoard is blocked by the
          // selection — clear it now so the Observer can schedule a rebuild.
          widget.viewModel.clearSelection();
        }

        // If a widget was selected, IgnorePointer is still blocking DrawingBoard
        // for this gesture (the MobX Observer hasn't rebuilt yet). Manually start
        // the drawing stroke so the first touch is not lost.
        final tool = widget.viewModel.drawingTools.activeTool;
        if (hadSelection && (tool == SelectableEditTool.pen || tool == SelectableEditTool.eraser)) {
          widget.drawingController.addFingerCount(event.localPosition);
          widget.drawingController.startDraw(event.localPosition);
          widget.onDrawingStrokeStart();
          _drawingStartedManually = true;
        }
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_drawingStartedManually && event.pointer == _firstPointerId) {
      widget.drawingController.drawing(event.localPosition);
      setState(() => _pointerPosition = event.localPosition);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _firstPointerId) {
      final wasEmpty = _tapCandidateOnEmptySpace;
      final startPos = _initialTouchPosition;
      _firstPointerId = null;
      _initialTouchPosition = null;
      _tapCandidateOnEmptySpace = false;

      if (_drawingStartedManually) {
        _drawingStartedManually = false;
        setState(() => _pointerPosition = null);
        widget.drawingController.endDraw();
        widget.drawingController.reduceFingerCount(event.localPosition);
        widget.onDrawingStrokeEnd();
        return;
      }

      // If the touch started on empty canvas and didn't move much, it's a tap
      // to deselect. This handles cases where ScaleGestureRecognizer doesn't
      // fire (movement below slop) and also touchscreen jitter.
      if (wasEmpty && startPos != null) {
        final movement = (event.localPosition - startPos).distance;
        if (movement < 10.0) {
          final isMultiSelect = HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;
          if (!isMultiSelect) widget.viewModel.clearSelection();
        }
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _firstPointerId) {
      if (_drawingStartedManually) {
        _drawingStartedManually = false;
        setState(() => _pointerPosition = null);
        widget.drawingController.cancelDraw();
        widget.drawingController.reduceFingerCount(event.localPosition);
      }
      _firstPointerId = null;
      _initialTouchPosition = null;
      _tapCandidateOnEmptySpace = false;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_handleDragActive) return;
    _lastFocalPoint = details.localFocalPoint;
    _gestureMovedSignificantly = false;
    _autoSelectedForDrag = false;

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
    for (final bw in widget.viewModel.boardWidgets.reversed) {
      if (_isPointOnWidget(checkPoint, bw)) {
        setState(() => _activeWidgetId = bw.id);
        _currentX = bw.x;
        _currentY = bw.y;
        _gestureStartRotation = bw.rotation;
        _gestureStartScale = bw.scale;
        widget.viewModel
          ..setActiveColor(null)
          ..setActiveTool(SelectableEditTool.pointer);
        widget.onWidgetTransformStart(bw.id);
        return;
      }
    }
    _activeWidgetId = null;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_handleDragActive) return;
    final delta = details.localFocalPoint - _lastFocalPoint!;
    _lastFocalPoint = details.localFocalPoint;
    if (delta.distance > 3.0) _gestureMovedSignificantly = true;

    if (_activeWidgetId == null) return;
    _currentX += delta.dx;
    _currentY += delta.dy;

    // Auto-select the dragged widget only once significant movement is confirmed
    // (i.e. it's a real drag, not a tap with touchscreen slop). Gating on
    // _gestureMovedSignificantly prevents clearing a multi-selection when the
    // user Ctrl/Cmd-taps — taps are handled in _onScaleEnd with the modifier key.
    if (!_autoSelectedForDrag && _gestureMovedSignificantly) {
      if (!widget.viewModel.selectedWidgetIds.contains(_activeWidgetId)) {
        widget.viewModel.selectWidget(_activeWidgetId!);
      }
      _autoSelectedForDrag = true;
    }

    final selectedIds = widget.viewModel.selectedWidgetIds;
    final isMultiMove = selectedIds.length > 1 && selectedIds.contains(_activeWidgetId);

    if (isMultiMove) {
      for (final bw in widget.viewModel.boardWidgets) {
        if (selectedIds.contains(bw.id)) {
          widget.viewModel.updateBoardWidget(bw.id, bw.x + delta.dx, bw.y + delta.dy, bw.rotation, bw.scale);
        }
      }
    } else {
      final newRotation = _gestureStartRotation + details.rotation;
      final newScale = (_gestureStartScale * details.scale).clamp(0.2, 5.0);
      widget.viewModel.updateBoardWidget(_activeWidgetId!, _currentX, _currentY, newRotation, newScale);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_handleDragActive) return;
    // pointerCount > 0 means fingers are still active: this end was triggered by
    // a finger-count change mid-gesture (ScaleGestureRecognizer calls onEnd then
    // defers onStart until the next move). Keep _activeWidgetId so the upcoming
    // onScaleStart can enter the mid-gesture branch instead of re-detecting.
    if (details.pointerCount == 0) {
      if (_gestureMovedSignificantly && _activeWidgetId != null) {
        widget.onWidgetTransformEnd(_activeWidgetId!);
      }
      if (!_gestureMovedSignificantly && _activeWidgetId != null) {
        final isMultiSelect = HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;
        widget.viewModel.selectWidget(_activeWidgetId!, multiSelect: isMultiSelect);
      }
      setState(() => _activeWidgetId = null);
      _firstPointerId = null;
      _initialTouchPosition = null;
      _tapCandidateOnEmptySpace = false;
      _gestureMovedSignificantly = false;
      _autoSelectedForDrag = false;
    }
    _lastFocalPoint = null;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final selected = widget.viewModel.selectedWidgetIds;
    if (selected.length != 1) return;
    final bwId = selected.first;
    final matching = widget.viewModel.boardWidgets.where((b) => b.id == bwId);
    if (matching.isEmpty) return;
    final bw = matching.first;
    if (!_isPointOnWidget(event.localPosition, bw)) return;

    const sensitivity = 0.001;
    final newScale = (bw.scale * (1.0 - event.scrollDelta.dy * sensitivity)).clamp(0.2, 5.0);

    if (_scrollEndTimer == null) widget.onWidgetTransformStart(bwId);
    _scrollEndTimer?.cancel();
    _scrollEndTimer = Timer(const Duration(milliseconds: 400), () {
      widget.onWidgetTransformEnd(bwId);
      _scrollEndTimer = null;
    });
    widget.viewModel.updateBoardWidget(bwId, bw.x, bw.y, bw.rotation, newScale);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      final board = widget.viewModel.board;
      return Container(
        decoration: BoxDecoration(
          border: board.backgroundColor == Colors.white
              ? BoxBorder.all(width: 1, color: Colors.black.withValues(alpha: 0.12), strokeAlign: BorderSide.strokeAlignOutside)
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
                  ignoring: _activeWidgetId != null || widget.viewModel.selectedWidgetIds.isNotEmpty,
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
                    onPointerDown: (pde) {
                      setState(() => _pointerPosition = pde.localPosition);
                      final tool = widget.viewModel.drawingTools.activeTool;
                      if (tool == SelectableEditTool.pen || tool == SelectableEditTool.eraser) {
                        widget.onDrawingStrokeStart();
                      }
                    },
                    onPointerMove: (pme) => setState(() => _pointerPosition = pme.localPosition),
                    onPointerUp: (pue) {
                      setState(() => _pointerPosition = null);
                      final tool = widget.viewModel.drawingTools.activeTool;
                      if (tool == SelectableEditTool.pen || tool == SelectableEditTool.eraser) {
                        widget.onDrawingStrokeEnd();
                      }
                    },
                    boardPanEnabled: false,
                    boardScaleEnabled: false,
                  ),
                ),
                for (final bw in widget.viewModel.boardWidgets)
                  ManipulableBoardWidget(
                    key: ValueKey(bw.id),
                    boardWidget: bw,
                    child: _buildWidgetContent(bw),
                  ),
                // Selection overlays — inside FittedBox so coords match widget coords.
                // Sized at boardPixelRatio-scaled canvas units to appear at host scale.
                for (final bw in widget.viewModel.boardWidgets)
                  if (widget.viewModel.selectedWidgetIds.contains(bw.id))
                    Positioned.fill(
                      child: WidgetSelectionOverlay(
                        key: ValueKey('sel_${bw.id}'),
                        boardWidget: bw,
                        boardPixelRatio: widget.viewModel.boardPixelRatio,
                        onDelete: () => widget.onDeleteWidget(bw.id),
                        settingsBuilder: (context) => _buildSettingsItems(context, bw),
                        onHandleTransformStart: () {
                          _handleDragActive = true;
                          widget.onWidgetTransformStart(bw.id);
                        },
                        onHandleTransformUpdate: (rotation, scale) {
                          widget.viewModel.updateBoardWidget(bw.id, bw.x, bw.y, rotation, scale);
                        },
                        onHandleTransformEnd: () {
                          _handleDragActive = false;
                          widget.onWidgetTransformEnd(bw.id);
                        },
                      ),
                    ),
                // Zero-size anchor for the right-click context menu flyout.
                // Positioned at the cursor's canvas coordinates so the flyout
                // appears exactly where the user right-clicked.
                if (_contextMenuCanvasPos != null)
                  Positioned(
                    left: _contextMenuCanvasPos!.dx,
                    top: _contextMenuCanvasPos!.dy,
                    width: 0,
                    height: 0,
                    child: FlyoutTarget(
                      controller: _contextMenuController,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                if (_eraseStrokeWidth != null && _pointerPosition != null)
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
                // ValueKey keeps Flutter from discarding the RawGestureDetector
                // state when the Stack gains/loses WidgetSelectionOverlay children
                // (which shifts this child's index and would otherwise lose the
                // active recognizer state mid-gesture).
                Positioned.fill(
                  key: const ValueKey('gesture-layer'),
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    onPointerSignal: _onPointerSignal,
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
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _contextMenuController.dispose();
    _scrollEndTimer?.cancel();
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    super.dispose();
  }

}
