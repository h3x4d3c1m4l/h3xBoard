import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent, PointerSignalEvent, kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/drawing_tools.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/background_lines.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/board_background_image.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/chalkboard_background.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/widget_header_bar.dart';
import 'package:h3xboard/views/board_screen/components/widgets/widget_selection_overlay.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class Board extends StatefulWidget {

  final DrawingController drawingController;
  final BoardScreenViewModel viewModel;

  /// Attached to the [RepaintBoundary] wrapping the board's visual layers
  /// (background, drawings and widget bodies — no header/overlay chrome), so the
  /// controller can grab a clean screenshot of the canvas to use as a thumbnail.
  final GlobalKey captureKey;

  final void Function(String id) onDeleteWidget;
  final void Function(String id, BoardWidgetConfig config) onWidgetConfigChanged;
  final void Function(String id, bool isGlobal) onWidgetVisibilityChanged;
  final void Function(String id) onWidgetTransformStart;
  final void Function(String id) onWidgetTransformEnd;
  final VoidCallback onDrawingStrokeStart;
  final VoidCallback onDrawingStrokeEnd;
  final void Function(String id) onMoveWidgetToTop;
  final void Function(String id) onMoveWidgetUp;
  final void Function(String id) onMoveWidgetDown;
  final void Function(String id) onMoveWidgetToBottom;

  const Board({
    super.key,
    required this.drawingController,
    required this.viewModel,
    required this.captureKey,
    required this.onDeleteWidget,
    required this.onWidgetConfigChanged,
    required this.onWidgetVisibilityChanged,
    required this.onWidgetTransformStart,
    required this.onWidgetTransformEnd,
    required this.onDrawingStrokeStart,
    required this.onDrawingStrokeEnd,
    required this.onMoveWidgetToTop,
    required this.onMoveWidgetUp,
    required this.onMoveWidgetDown,
    required this.onMoveWidgetToBottom,
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

  // Distinguishes a tap from a drag (move intent).
  // Set to true as soon as cumulative movement in a gesture exceeds 3 canvas px.
  bool _gestureMovedSignificantly = false;

  // True while a Use-mode header drag is in progress (move-only, no rotate/scale).
  // The dragged widget is tracked by _activeWidgetId.
  bool _headerDragActive = false;

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

  // Debounces arrow-key nudges of the arranging widget into a single undo history entry.
  Timer? _arrowEndTimer;
  String? _arrowNudgeWidgetId;

  @override
  void initState() {
    widget.drawingController.drawConfig.addListener(_onDrawConfigChanged);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    super.initState();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final arrangingId = widget.viewModel.arrangingWidgetId;

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      if (arrangingId == null) return false;
      widget.viewModel.setArrangingWidget(null);
      return true;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace)) {
      if (arrangingId == null) return false;
      widget.onDeleteWidget(arrangingId);
      widget.viewModel.setArrangingWidget(null);
      return true;
    }

    // Arrow keys nudge the arranging widget. Shift = larger step.
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => const Offset(-1, 0),
      LogicalKeyboardKey.arrowRight => const Offset(1, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, -1),
      LogicalKeyboardKey.arrowDown => const Offset(0, 1),
      _ => null,
    };
    if (delta != null && arrangingId != null) {
      _nudgeArrangingWidget(arrangingId, delta * (HardwareKeyboard.instance.isShiftPressed ? 10.0 : 1.0));
      return true;
    }
    return false;
  }

  // Moves the arranging widget by [delta] canvas px, coalescing key-repeat bursts
  // into a single undo history entry via a trailing timer.
  void _nudgeArrangingWidget(String id, Offset delta) {
    final matching = widget.viewModel.visibleBoardWidgets.where((b) => b.id == id);
    if (matching.isEmpty) return;
    final bw = matching.first;
    if (_arrowEndTimer == null) {
      widget.onWidgetTransformStart(id);
      _arrowNudgeWidgetId = id;
    }
    _arrowEndTimer?.cancel();
    _arrowEndTimer = Timer(const Duration(milliseconds: 400), () {
      final nudged = _arrowNudgeWidgetId;
      _arrowEndTimer = null;
      _arrowNudgeWidgetId = null;
      if (nudged != null) widget.onWidgetTransformEnd(nudged);
    });
    widget.viewModel.updateBoardWidget(
      id,
      (bw.x + delta.dx).clamp(0.0, 1920.0),
      (bw.y + delta.dy).clamp(0.0, 1080.0),
      bw.rotation,
      bw.scale,
    );
  }

  void _onDrawConfigChanged() {
    setState(() {
      _eraseStrokeWidth = widget.drawingController.eraserContent?.paint.strokeWidth;
    });
  }

  Widget _buildWidgetContent(BoardWidget bw) {
    final descriptor = descriptorFor(bw.config);
    void onChange(BoardWidgetConfig newConfig) => widget.onWidgetConfigChanged(bw.id, newConfig);
    final content = descriptor.buildWidget(bw.config, onChange);

    // Double-clicking an editable widget's body opens its inline editor (the same
    // action offered in the settings menu). Widgets without an editor are unwrapped.
    final edit = descriptor.editAction(context, bw.config, onChange);
    if (edit == null) return content;
    return GestureDetector(
      onDoubleTap: edit,
      child: content,
    );
  }

  Widget _buildHeader(BuildContext context, BoardWidget bw) {
    final placement = _headerPlacementFor(bw);
    return WidgetHeaderBar(
      key: ValueKey('hdr_${bw.id}'),
      center: placement.center,
      size: placement.size,
      rotation: placement.rotation,
      arrangeDelta: placement.arrangeDelta,
      title: descriptorFor(bw.config).label(context.localizations),
      isArranging: bw.id == widget.viewModel.arrangingWidgetId,
      visible: widget.viewModel.drawingTools.activeTool == SelectableEditTool.pointer,
      settingsBuilder: (context) => _buildSettingsItems(context, bw),
      onToggleArrange: () => _toggleArrange(bw.id),
      onClose: () => widget.onDeleteWidget(bw.id),
    );
  }

  // Header pencil/Done toggle: enter Arrange on this widget, or — if it is already
  // arranging — return to Use mode. Drawing is suppressed while arranging.
  void _toggleArrange(String id) {
    widget.viewModel.setArrangingWidget(widget.viewModel.arrangingWidgetId == id ? null : id);
  }

  List<MenuFlyoutItemBase> _buildSettingsItems(BuildContext context, BoardWidget bw, {bool includeTitle = false}) {
    final descriptor = descriptorFor(bw.config);
    final typeItems = descriptor.settingsMenuItems(
      context,
      bw.config,
      (newConfig) => widget.onWidgetConfigChanged(bw.id, newConfig),
    );
    final visible = widget.viewModel.visibleBoardWidgets;
    final currentIndex = visible.indexWhere((w) => w.id == bw.id);
    final maxIndex = visible.length - 1;
    final isTop = currentIndex == maxIndex;
    final isBottom = currentIndex == 0;
    final isGlobal = bw.isVisibleOnAllBoards;
    return [
      // Right-click menus prepend the widget's identity so it's clear which widget
      // the menu belongs to (the header-bar settings button doesn't need it).
      if (includeTitle) ...[
        MenuFlyoutItemBuilder(
          builder: (context) => Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(descriptor.icon, size: 16),
                const SizedBox(width: 8),
                Text(
                  descriptor.label(context.localizations),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const MenuFlyoutSeparator(),
      ],
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
      MenuFlyoutSubItem(
        leading: const Icon(LucideIcons.eye),
        text: Text(context.localizations.boardVisibilityMenu_title),
        items: (_) => [
          MenuFlyoutItem(
            leading: Icon(isGlobal ? LucideIcons.checkCircle : LucideIcons.circle),
            text: Text(context.localizations.boardVisibilityMenu_allBoards),
            onPressed: isGlobal ? null : () => widget.onWidgetVisibilityChanged(bw.id, true),
          ),
          MenuFlyoutItem(
            leading: Icon(!isGlobal ? LucideIcons.checkCircle : LucideIcons.circle),
            text: Text(context.localizations.boardVisibilityMenu_thisBoard),
            onPressed: !isGlobal ? null : () => widget.onWidgetVisibilityChanged(bw.id, false),
          ),
        ],
      ),
      // Delete lives in the right-click menu only; the header-bar already has a
      // dedicated close (X) button for the same action.
      if (includeTitle) ...[
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          leading: Icon(LucideIcons.trash2, color: Colors.red),
          text: Text(
            context.localizations.boardWidget_remove,
            style: TextStyle(color: Colors.red),
          ),
          onPressed: () => widget.onDeleteWidget(bw.id),
        ),
      ],
    ];
  }

  // Canvas-space placement of a widget's header bar. The single source of truth for
  // both rendering (passed to WidgetHeaderBar) and hit-testing (_isPointOnHeader).
  // The header is attached above the widget's local top edge and shares the widget's
  // rotation. [center] is the Use-mode anchor (follows the widget instantly while
  // dragging); [arrangeDelta] is the extra push that clears the rotate handle while
  // arranging — animated separately so the mode change eases without lagging drags.
  ({Offset center, Size size, double rotation, Offset arrangeDelta}) _headerPlacementFor(BoardWidget bw) {
    final ratio = widget.viewModel.boardPixelRatio;
    final natural = naturalSizeFor(bw.config);
    final scaledH = natural.height * bw.scale;
    final r = bw.rotation;
    final borderMargin = kOverlayBorderMargin * ratio;
    final w = kHeaderWidth * ratio;
    final h = kHeaderHeight * ratio;
    final gap = kHeaderGap * ratio;
    final stem = kOverlayStemLength * ratio;
    final handleRadius = kOverlayHandleRadius * ratio;

    // Distance from the widget centre to the header centre, along the widget's local
    // "up" axis — in Use mode, and (pushed out to clear the rotate handle) in Arrange.
    final distUse = scaledH / 2 + borderMargin + gap + h / 2;
    final distArrange = scaledH / 2 + borderMargin + stem + 2 * handleRadius + gap + h / 2;
    final dir = Offset(math.sin(r), -math.cos(r));

    // Clamp each centre so the header's (rotation-aware) bounding box stays fully
    // on-canvas and readable even when the widget is dragged over the edge.
    final halfW = (w / 2) * math.cos(r).abs() + (h / 2) * math.sin(r).abs();
    final halfH = (w / 2) * math.sin(r).abs() + (h / 2) * math.cos(r).abs();
    Offset clampCenter(double dist) {
      final raw = Offset(bw.x, bw.y) + dir * dist;
      return Offset(
        raw.dx.clamp(halfW, math.max(halfW, 1920.0 - halfW)).toDouble(),
        raw.dy.clamp(halfH, math.max(halfH, 1080.0 - halfH)).toDouble(),
      );
    }

    final useCenter = clampCenter(distUse);
    final arrangeCenter = clampCenter(distArrange);
    return (center: useCenter, size: Size(w, h), rotation: r, arrangeDelta: arrangeCenter - useCenter);
  }

  bool _isPointOnHeader(Offset canvasPoint, BoardWidget bw) {
    final placement = _headerPlacementFor(bw);
    final center = bw.id == widget.viewModel.arrangingWidgetId
        ? placement.center + placement.arrangeDelta
        : placement.center;
    final d = canvasPoint - center;
    final cosA = math.cos(-placement.rotation);
    final sinA = math.sin(-placement.rotation);
    final localX = d.dx * cosA - d.dy * sinA;
    final localY = d.dx * sinA + d.dy * cosA;
    return localX.abs() <= placement.size.width / 2 && localY.abs() <= placement.size.height / 2;
  }

  // Topmost widget whose header contains the point, or null. Reversed so the
  // visually-topmost header wins when headers overlap. Headers (and their drag
  // affordance) exist only in Select mode, so this never matches otherwise.
  BoardWidget? _headerAt(Offset canvasPoint) {
    if (widget.viewModel.drawingTools.activeTool != SelectableEditTool.pointer) return null;
    for (final bw in widget.viewModel.visibleBoardWidgets.reversed) {
      if (_isPointOnHeader(canvasPoint, bw)) return bw;
    }
    return null;
  }

  // Returns true if canvasPoint is within a handle (rotation circle or corner scale square)
  // of the widget currently being arranged. Mirrors the geometry in WidgetSelectionOverlay
  // (44px finger-friendly touch targets) so the board's recognizer yields to handle drags.
  bool _isPointOnArrangeHandle(Offset canvasPoint) {
    final arrangingId = widget.viewModel.arrangingWidgetId;
    if (arrangingId == null) return false;
    final matching = widget.viewModel.visibleBoardWidgets.where((b) => b.id == arrangingId);
    if (matching.isEmpty) return false;
    final bw = matching.first;
    final ratio = widget.viewModel.boardPixelRatio;
    final touchRadius = kOverlayHandleTouch * ratio / 2;
    if ((canvasPoint - rotationHandleCenter(bw, ratio)).distance <= touchRadius) return true;
    for (final pos in cornerHandlePositions(bw, ratio)) {
      if ((canvasPoint - pos).distance <= touchRadius) return true;
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
      for (final bw in widget.viewModel.visibleBoardWidgets.reversed) {
        if (_isPointOnWidget(event.localPosition, bw) || _isPointOnHeader(event.localPosition, bw)) {
          _contextMenuCanvasPos = event.localPosition;
          _contextMenuBuilder = (context) => _buildSettingsItems(context, bw, includeTitle: true);
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

      // Tapping empty board (no header, body or arrange handle) while a widget is
      // being arranged exits Arrange mode.
      if (widget.viewModel.arrangingWidgetId != null) {
        final p = event.localPosition;
        final onSomething = _headerAt(p) != null ||
            _isPointOnArrangeHandle(p) ||
            widget.viewModel.visibleBoardWidgets.any((bw) => _isPointOnWidget(p, bw));
        if (!onSomething) widget.viewModel.setArrangingWidget(null);
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {}

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _firstPointerId) {
      _firstPointerId = null;
      _initialTouchPosition = null;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    // Widget drags (header / arrange body) are scale gestures, so _onScaleEnd
    // fires on cancel and finalises the transform. Here we only clear the raw
    // pointer tracking used for pre-slop hit-testing.
    if (event.pointer == _firstPointerId) {
      _firstPointerId = null;
      _initialTouchPosition = null;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_handleDragActive) return;
    _lastFocalPoint = details.localFocalPoint;
    _gestureMovedSignificantly = false;

    if (_activeWidgetId != null) {
      // Finger count changed mid-gesture: keep tracking the same widget but
      // reset rotation/scale baselines to the current accumulated values.
      final bw = widget.viewModel.boardWidgets.firstWhere((b) => b.id == _activeWidgetId);
      _gestureStartRotation = bw.rotation;
      _gestureStartScale = bw.scale;
      return;
    }

    // Use the Listener-recorded initial touch position (pre-slop) rather than
    // details.localFocalPoint (post-slop) for accurate hit-testing.
    final checkPoint = _initialTouchPosition ?? details.localFocalPoint;

    // 1) Header drag (Use mode): move-only, available on any widget at any time.
    final headerWidget = _headerAt(checkPoint);
    if (headerWidget != null) {
      _headerDragActive = true;
      setState(() => _activeWidgetId = headerWidget.id);
      _currentX = headerWidget.x;
      _currentY = headerWidget.y;
      _gestureStartRotation = headerWidget.rotation;
      _gestureStartScale = headerWidget.scale;
      widget.onWidgetTransformStart(headerWidget.id);
      return;
    }

    // 2) Arrange-mode body drag: only the arranging widget's body is grabbable.
    final arrangingId = widget.viewModel.arrangingWidgetId;
    if (arrangingId != null) {
      final matching = widget.viewModel.visibleBoardWidgets.where((b) => b.id == arrangingId);
      if (matching.isNotEmpty && _isPointOnWidget(checkPoint, matching.first)) {
        final bw = matching.first;
        setState(() => _activeWidgetId = bw.id);
        _currentX = bw.x;
        _currentY = bw.y;
        _gestureStartRotation = bw.rotation;
        _gestureStartScale = bw.scale;
        widget.onWidgetTransformStart(bw.id);
        return;
      }
    }

    // 3) Anything else (a live Use-mode body) is left for the widget body itself.
    _activeWidgetId = null;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_handleDragActive) return;
    final delta = details.localFocalPoint - _lastFocalPoint!;
    _lastFocalPoint = details.localFocalPoint;
    if (delta.distance > 3.0) _gestureMovedSignificantly = true;

    if (_activeWidgetId == null) return;
    _currentX = (_currentX + delta.dx).clamp(0.0, 1920.0);
    _currentY = (_currentY + delta.dy).clamp(0.0, 1080.0);

    if (_headerDragActive) {
      // Header drag is move-only: never rotate or scale.
      widget.viewModel.updateBoardWidget(
        _activeWidgetId!,
        _currentX,
        _currentY,
        _gestureStartRotation,
        _gestureStartScale,
      );
      return;
    }

    // Arrange-mode body drag: move + two-finger rotate/scale (Shift snaps rotation to 15°).
    var newRotation = _gestureStartRotation + details.rotation;
    if (HardwareKeyboard.instance.isShiftPressed) {
      const step = math.pi / 12;
      newRotation = (newRotation / step).round() * step;
    }
    // Grid-matched rulers own their scale: keep it fixed (move + rotate still apply).
    final active = widget.viewModel.visibleBoardWidgets.where((b) => b.id == _activeWidgetId);
    final scaleLocked = active.isNotEmpty && active.first.isScaleLocked;
    final newScale = scaleLocked ? _gestureStartScale : (_gestureStartScale * details.scale).clamp(0.2, 5.0);
    widget.viewModel.updateBoardWidget(_activeWidgetId!, _currentX, _currentY, newRotation, newScale);
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
      setState(() => _activeWidgetId = null);
      _headerDragActive = false;
      _firstPointerId = null;
      _initialTouchPosition = null;
      _gestureMovedSignificantly = false;
    }
    _lastFocalPoint = null;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final bwId = widget.viewModel.arrangingWidgetId;
    if (bwId == null) return;
    final matching = widget.viewModel.visibleBoardWidgets.where((b) => b.id == bwId);
    if (matching.isEmpty) return;
    final bw = matching.first;
    if (!_isPointOnWidget(event.localPosition, bw)) return;
    if (bw.isScaleLocked) return; // grid-matched rulers ignore scroll-zoom

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
                // Everything the screenshot should capture — background, drawings
                // and widget bodies — lives under this RepaintBoundary. Header/
                // overlay chrome and the gesture layer are stacked on top of it, so
                // they stay out of the captured thumbnail.
                Positioned.fill(
                  child: RepaintBoundary(
                    key: widget.captureKey,
                    child: Stack(
                      children: [
                // Drawing is suppressed in Select mode (the user is managing
                // widgets, not drawing) and while a widget is being arranged; the
                // headers absorb pointers to block strokes underneath them, and
                // interactive bodies capture their own taps.
                IgnorePointer(
                  ignoring: widget.viewModel.drawingTools.activeTool == SelectableEditTool.pointer ||
                      widget.viewModel.arrangingWidgetId != null,
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
                      final backgroundFileId = board.backgroundFileId;
                      if (backgroundFileId != null) {
                        return BoardBackgroundImage(
                          fileId: backgroundFileId,
                          fallbackColor: board.backgroundColor,
                          fileService: GetIt.I<H3xBoardFileService>(),
                          child: box,
                        );
                      }
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
                // Widget bodies. Bodies keep their own interactivity (stopwatch
                // buttons, piano keys) and pointers fall through to the drawing layer
                // over non-interactive ones. The widget being arranged is dimmed and
                // its body interaction paused.
                for (final bw in widget.viewModel.visibleBoardWidgets)
                  ManipulableBoardWidget(
                    key: ValueKey(bw.id),
                    boardWidget: bw,
                    child: IgnorePointer(
                      ignoring: bw.id == widget.viewModel.arrangingWidgetId,
                      child: Opacity(
                        opacity: bw.id == widget.viewModel.arrangingWidgetId ? 0.6 : 1.0,
                        child: _buildWidgetContent(bw),
                      ),
                    ),
                  ),
                      ],
                    ),
                  ),
                ),
                // Header chrome — always mounted but faded out (and pointer-inert)
                // outside Select mode, so toggling the mode animates in/out and the
                // board stays uncluttered while drawing or presenting.
                for (final bw in widget.viewModel.visibleBoardWidgets) _buildHeader(context, bw),
                // Arrange overlay (solid border + resize/rotate handles) for the
                // single widget being arranged. Sized at boardPixelRatio-scaled
                // canvas units to appear at host scale.
                for (final bw in widget.viewModel.visibleBoardWidgets)
                  if (bw.id == widget.viewModel.arrangingWidgetId)
                    Positioned.fill(
                      child: WidgetSelectionOverlay(
                        key: ValueKey('sel_${bw.id}'),
                        boardWidget: bw,
                        boardPixelRatio: widget.viewModel.boardPixelRatio,
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
    _arrowEndTimer?.cancel();
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    super.dispose();
  }

}
