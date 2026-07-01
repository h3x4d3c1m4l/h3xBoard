import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_content.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/drawing_tools.dart';
import 'package:h3xboard/services/fullscreen_service.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/board_settings_dialog.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/widget_catalog_dialog.dart';
import 'package:h3xboard/views/board_screen/history/history_entry.dart';
import 'package:h3xboard/views/board_screen/history/history_manager.dart';
import 'package:h3xboard/widgets/themable_loading_dialog.dart';

// Matches 'Board N' titles to pick the next auto-number.
final _boardTitleRegex = RegExp(r'^Board (\d+)$');

// How long to wait after the last change before persisting the board.
const _autosaveDebounce = Duration(seconds: 1);

// How often, at most, to refresh the board's thumbnail while it is being edited.
const _screenshotInterval = Duration(minutes: 5);

class BoardScreenController extends ScreenControllerBase<BoardScreenViewModel> {

  final String boardId;

  final DrawingController drawingController = DrawingController();

  /// Wraps the board's visual layers so [_captureScreenshot] can rasterise the
  /// canvas into a thumbnail when the user leaves the board.
  final GlobalKey boardCaptureKey = GlobalKey();

  final HistoryManager historyManager = HistoryManager();
  final ValueNotifier<int> drawStartSignal = ValueNotifier(0);
  final FullscreenService _fullscreenService = FullscreenService();
  final _wsClient = GetIt.I<H3xBoardApiClient>();
  final _fileService = GetIt.I<H3xBoardFileService>();

  // Pending state captured at gesture/stroke boundaries for history recording.
  List<Map<String, dynamic>>? _drawingBefore;
  Map<String, (double, double, double, double)>? _transformBefore;
  String? _transformBoardId;

  // Autosave bookkeeping.
  Timer? _saveTimer;
  Future<void>? _activeSave;
  bool _saveDirty = false;

  // Thumbnail bookkeeping. The screenshot is refreshed at most once every
  // [_screenshotInterval] while editing (and once on close), but only when the
  // board changed since the last upload — a clean board never re-uploads.
  Timer? _screenshotTimer;
  bool _screenshotDirty = false;
  bool _screenshotBusy = false;

  StreamSubscription<bool>? _fullscreenSubscription;

  // Initialization/Deinitialization

  BoardScreenController({
    required this.boardId,
    required super.viewModel,
    required super.contextAccessor,
  }) {
    drawingController.setStyle(color: viewModel.drawingTools.activeColor);
    _fullscreenSubscription = _fullscreenService.onChange.listen(viewModel.setFullscreen);
    // Every undoable step is also a save point, mirroring the undo history.
    historyManager.onChange = _scheduleSave;
    // Refresh the thumbnail on a slow cadence while editing (no-op when clean).
    _screenshotTimer = Timer.periodic(_screenshotInterval, (_) => unawaited(_captureScreenshotIfDirty()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBoard());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _screenshotTimer?.cancel();
    _fullscreenSubscription?.cancel();
    _fullscreenService.dispose();
    super.dispose();
    drawingController.dispose();
    drawStartSignal.dispose();
  }

  // Persistence

  Future<void> _loadBoard() async {
    viewModel
      ..setIsLoading(true)
      ..setLoadError(null);
    try {
      final detail = await _wsClient.getBoard(boardId);
      final content = detail.data.isEmpty ? const BoardContent() : BoardContent.fromJson(detail.data);
      viewModel.setInitialContent(content);
      drawingController.clear();
      final saved = viewModel.restoreSubBoardDrawing(viewModel.activeSubBoardId);
      if (saved.isNotEmpty) {
        drawingController.addContents(_restoreDrawingContents(saved));
      }
    } on H3xBoardApiException catch (e) {
      viewModel.setLoadError(e.message);
    } catch (e) {
      viewModel.setLoadError(e.toString());
    } finally {
      viewModel.setIsLoading(false);
    }
  }

  void retryLoad() => unawaited(_loadBoard());

  void _scheduleSave() {
    _saveDirty = true;
    // Any change that warrants a save also makes the thumbnail stale.
    _screenshotDirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_autosaveDebounce, _save);
  }

  /// Kicks off a save if one isn't already running. Coalesces with any active
  /// save: changes landing mid-save are flushed by a follow-up scheduled in the
  /// `finally` block.
  void _save() {
    if (_activeSave != null) return;
    if (!_saveDirty) return;
    _activeSave = _runSave().whenComplete(() => _activeSave = null);
  }

  Future<void> _runSave() async {
    _saveDirty = false;
    viewModel.setSaveStatus(BoardSaveStatus.saving);
    try {
      await _wsClient.updateBoard(id: boardId, data: _buildContent().toJson());
      viewModel.setSaveStatus(_saveDirty ? BoardSaveStatus.saving : BoardSaveStatus.saved);
    } catch (_) {
      _saveDirty = true;
      viewModel.setSaveStatus(BoardSaveStatus.error);
    } finally {
      // A change landed mid-save (or the save failed); try again.
      if (_saveDirty) _scheduleSave();
    }
  }

  /// Forces any unsaved changes to disk and waits for the write to land.
  /// Returns `true` once everything is persisted, `false` if the save failed.
  Future<bool> _flushPendingSave() async {
    _saveTimer?.cancel();
    // Let an in-flight save settle, then drain whatever it didn't include.
    if (_activeSave != null) await _activeSave;
    if (_saveDirty) {
      _save();
      await _activeSave;
    }
    return !_saveDirty;
  }

  /// Snapshots the current editor state, folding the live drawing on the active
  /// board (which only lands in the view model on board switch) into the map.
  BoardContent _buildContent() {
    final drawings = <String, List<Map<String, dynamic>>>{
      for (final e in viewModel.subBoardDrawings.entries) e.key: e.value,
    };
    drawings[viewModel.activeSubBoardId] = drawingController.getJsonList();
    return BoardContent(
      subBoards: viewModel.subBoards.toList(),
      activeSubBoardId: viewModel.activeSubBoardId,
      widgets: viewModel.boardWidgets.toList(),
      drawings: drawings,
    );
  }

  // Navigation

  // Guards against re-entrancy: the close button, system/browser back and the
  // imperative pop below all funnel through requestClose.
  bool _isClosing = false;

  /// Handles a request to leave the board (close button or system/browser back).
  /// Flushes pending changes — showing a spinner while they persist — then pops
  /// back to the boards overview. Stays on the board if the save fails so no
  /// work is silently lost.
  Future<void> requestClose() async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      final context = contextAccessor.buildContext;
      final navigator = Navigator.of(context);

      if (_saveDirty || _activeSave != null) {
        BuildContext? dialogContext;
        unawaited(showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            dialogContext = ctx;
            return ThemableLoadingDialog(message: localizations.boardScreen_closing);
          },
        ));
        final saved = await _flushPendingSave();
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.of(dialogContext!).pop();
        }
        // Keep the user on the board so they can retry rather than lose work.
        if (!saved) return;
      }

      // Refresh the thumbnail only when the board changed since the last upload,
      // and (unlike the periodic capture) wait for it — capped, so a slow network
      // can't trap the user — so the boards overview shows the new image the
      // moment it reloads on return. Screenshot uploads don't bump updatedAt, so
      // this never reorders the list.
      _screenshotTimer?.cancel();
      if (_screenshotDirty && !_screenshotBusy) {
        _screenshotDirty = false;
        final screenshot = await _captureScreenshot();
        if (screenshot != null) {
          try {
            await _fileService
                .setBoardScreenshot(boardId: boardId, bytes: screenshot)
                .timeout(const Duration(seconds: 3));
          } catch (_) {
            // Best-effort; the thumbnail will catch up on a later save/close.
          }
        }
      }
      if (navigator.mounted) navigator.pop();
    } finally {
      _isClosing = false;
    }
  }

  /// Uploads a fresh thumbnail when the board changed since the last upload.
  /// Driven by the periodic timer, so it stays entirely in the background and
  /// never blocks the UI; a clean board is a no-op. Re-marks the board dirty on
  /// failure so the next tick (or close) retries.
  Future<void> _captureScreenshotIfDirty() async {
    if (!_screenshotDirty || _screenshotBusy) return;
    _screenshotBusy = true;
    _screenshotDirty = false;
    try {
      final bytes = await _captureScreenshot();
      if (bytes == null) {
        _screenshotDirty = true;
        return;
      }
      await _fileService.setBoardScreenshot(boardId: boardId, bytes: bytes);
    } catch (_) {
      _screenshotDirty = true;
    } finally {
      _screenshotBusy = false;
    }
  }

  /// Rasterises the board's visual layers (background, drawings, widget bodies —
  /// no header/overlay chrome) to PNG bytes for use as a list thumbnail. Rendered
  /// at half the 1920×1080 canvas resolution to keep the upload small. Returns
  /// `null` if the boundary isn't ready or capture fails (best-effort).
  Future<Uint8List?> _captureScreenshot() async {
    try {
      // Ensure the canvas has painted a frame before rasterising it, otherwise
      // toImage can throw on a boundary still marked as needing paint.
      await WidgetsBinding.instance.endOfFrame;
      final boundary = boardCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 0.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // Fullscreen handler

  void onFullscreenToggle() {
    if (_fullscreenService.isFullscreen) {
      _fullscreenService.exitFullscreen();
    } else {
      _fullscreenService.requestFullscreen();
    }
  }

  // Drawing tool handlers

  void onColorButtonPressed(Color value) {
    viewModel
      ..setActiveColor(value)
      ..setActiveTool(.pen)
      ..setArrangingWidget(null);
    drawingController
      ..setPaintContent(SimpleLine())
      ..setStyle(color: value, strokeWidth: viewModel.drawingTools.penWidth);
  }

  void onSelectableToolButtonPressed(SelectableEditTool value) {
    switch (value) {
      case .pointer:
        viewModel.setActiveColor(null);
      case .pen:
        if (viewModel.drawingTools.activeColor == null) {
          viewModel.setActiveColor(viewModel.drawingTools.lastActiveColor);
        }
        drawingController.setPaintContent(SimpleLine());
        drawingController.setStyle(strokeWidth: viewModel.drawingTools.penWidth);
        viewModel.setArrangingWidget(null);
      case .eraser:
        viewModel.setActiveColor(null);
        drawingController.setPaintContent(Eraser());
        drawingController.setStyle(strokeWidth: viewModel.drawingTools.eraserWidth);
        viewModel.setArrangingWidget(null);
    }

    viewModel.setActiveTool(value);
  }

  void onPenWidthSliderMoved(double value) {
    drawingController.setStyle(strokeWidth: value);
    viewModel.setPenWidth(value);
  }

  void onEraserWidthSliderMoved(double value) {
    drawingController.setStyle(strokeWidth: value);
    viewModel.setEraserWidth(value);
  }

  // Drawing stroke history callbacks (called by Board)

  void onDrawingStrokeStart() {
    _drawingBefore = drawingController.getJsonList();
    drawStartSignal.value++;
  }

  void onDrawingStrokeEnd() {
    final before = _drawingBefore;
    _drawingBefore = null;
    if (before == null) return;
    final after = drawingController.getJsonList();
    if (after.length == before.length) return;
    final boardId = viewModel.activeSubBoardId;
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        drawingController.clear();
        if (before.isNotEmpty) drawingController.addContents(_restoreDrawingContents(before));
      },
      redo: () {
        _ensureActiveBoard(boardId);
        drawingController.clear();
        if (after.isNotEmpty) drawingController.addContents(_restoreDrawingContents(after));
      },
    ));
  }

  void onClearButtonPressed() {
    final before = drawingController.getJsonList();
    if (before.isEmpty) return;
    final boardId = viewModel.activeSubBoardId;
    drawingController.clear();
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        drawingController
          ..clear()
          ..addContents(_restoreDrawingContents(before));
      },
      redo: () {
        _ensureActiveBoard(boardId);
        drawingController.clear();
      },
    ));
  }

  // Widget handlers

  /// Opens the widget catalog and adds the chosen widget to the board. Does
  /// nothing if the dialog is dismissed without a selection.
  Future<void> onShowWidgetCatalog() async {
    final context = contextAccessor.buildContext;
    final config = await showDialog<BoardWidgetConfig>(
      context: context,
      builder: (_) => const WidgetCatalogDialog(),
      barrierDismissible: true,
    );
    if (config == null) return;
    onAddWidget(config);
  }

  void onAddWidget(BoardWidgetConfig config) {
    // Switch to Select mode so the new widget's header is visible and it can be
    // positioned right away (headers are hidden in Draw/Erase mode).
    if (viewModel.drawingTools.activeTool != SelectableEditTool.pointer) {
      onSelectableToolButtonPressed(SelectableEditTool.pointer);
    }
    final id = '${config.runtimeType}_${DateTime.now().millisecondsSinceEpoch}';
    final boardId = viewModel.activeSubBoardId;
    final widget = BoardWidget(
      id: id,
      config: config,
      x: 960,
      y: 540,
      visibleOnBoardIds: [boardId],
    );
    viewModel.addBoardWidget(widget);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.removeBoardWidget(id);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.addBoardWidget(widget);
      },
    ));
  }

  void onAddSubBoard() {
    final previousId = viewModel.activeSubBoardId;
    final existingNumbers = viewModel.subBoards
        .map((b) => _boardTitleRegex.firstMatch(b.title)?.group(1))
        .whereType<String>()
        .map(int.parse)
        .toList();
    final nextNumber = (existingNumbers.isEmpty ? 0 : existingNumbers.reduce((a, b) => a > b ? a : b)) + 1;
    final id = 'board_${DateTime.now().millisecondsSinceEpoch}';
    final board = Board(
      id: id,
      title: 'Board $nextNumber',
      backgroundColor: Colors.white,
      isChalkboard: false,
      linePattern: BoardLinePattern.none,
      lineSpacing: 64,
      lineColor: Colors.grey[100],
    );
    viewModel.addSubBoard(board);
    onSwitchSubBoard(id);
    historyManager.push(HistoryEntry(
      undo: () {
        onSwitchSubBoard(previousId);
        viewModel.removeSubBoard(id);
      },
      redo: () {
        viewModel.addSubBoard(board);
        onSwitchSubBoard(id);
      },
    ));
  }

  void onRemoveSubBoard(String id) {
    if (viewModel.subBoards.length <= 1) return;
    final boards = viewModel.subBoards;
    final idx = boards.indexWhere((b) => b.id == id);
    final removedBoard = boards[idx];
    final removedWidgets = viewModel.boardWidgets
        .where((w) => !w.isVisibleOnAllBoards && w.visibleOnBoardIds.every((bid) => bid == id))
        .toList();
    final switchTargetId = idx > 0 ? boards[idx - 1].id : boards[idx + 1].id;
    if (viewModel.activeSubBoardId == id) {
      onSwitchSubBoard(switchTargetId);
    }
    viewModel.removeSubBoard(id);
    historyManager.push(HistoryEntry(
      undo: () {
        viewModel.addSubBoard(removedBoard);
        for (final w in removedWidgets) {
          viewModel.addBoardWidget(w);
        }
        onSwitchSubBoard(id);
      },
      redo: () {
        if (viewModel.activeSubBoardId == id) onSwitchSubBoard(switchTargetId);
        viewModel.removeSubBoard(id);
      },
    ));
  }

  void onRenameSubBoard(String id, String newTitle) {
    final oldTitle = viewModel.subBoards.firstWhere((b) => b.id == id).title;
    if (oldTitle == newTitle) return;
    viewModel.renameSubBoard(id, newTitle);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.renameSubBoard(id, oldTitle),
      redo: () => viewModel.renameSubBoard(id, newTitle),
    ));
  }

  void onSwitchSubBoard(String id) {
    final currentId = viewModel.activeSubBoardId;
    if (currentId == id) return;
    viewModel.saveSubBoardDrawing(currentId, drawingController.getJsonList());
    drawingController.clear();
    viewModel.setActiveSubBoardId(id);
    final saved = viewModel.restoreSubBoardDrawing(id);
    if (saved.isNotEmpty) {
      drawingController.addContents(_restoreDrawingContents(saved));
    }
  }

  void onWidgetVisibilityChanged(String widgetId, bool isGlobal) {
    final widget = viewModel.boardWidgets.firstWhere((w) => w.id == widgetId);
    final boardId = viewModel.activeSubBoardId;
    final oldIsGlobal = widget.isVisibleOnAllBoards;
    final oldBoardIds = widget.visibleOnBoardIds;
    final newBoardIds = isGlobal ? <String>[] : [boardId];
    viewModel.updateBoardWidgetVisibility(widgetId, isGlobal, newBoardIds);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.updateBoardWidgetVisibility(widgetId, oldIsGlobal, oldBoardIds);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.updateBoardWidgetVisibility(widgetId, isGlobal, newBoardIds);
      },
    ));
  }

  void onDeleteWidget(String id) {
    final boardId = viewModel.activeSubBoardId;
    final widget = viewModel.boardWidgets.firstWhere((w) => w.id == id);
    viewModel.removeBoardWidget(id);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.addBoardWidget(widget);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.removeBoardWidget(id);
      },
    ));
  }

  void onWidgetConfigChanged(String id, BoardWidgetConfig newConfig) {
    final boardId = viewModel.activeSubBoardId;
    final old = viewModel.boardWidgets.firstWhere((w) => w.id == id);
    final oldConfig = old.config;
    final oldScale = old.scale;
    // A ruler's grid-match mode owns its scale; derive it from the current grid so
    // enabling a match snaps the ruler immediately. Both the config and the previous
    // (free) scale are captured so undo restores the size the ruler had before.
    final newScale = boardWidgetMatchScale(newConfig, viewModel.board.lineSpacing);

    void applyScale(double scale) {
      final w = viewModel.boardWidgets.firstWhere((w) => w.id == id);
      viewModel.updateBoardWidget(id, w.x, w.y, w.rotation, scale);
    }

    viewModel.updateBoardWidgetConfig(id, newConfig);
    if (newScale != null) applyScale(newScale);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.updateBoardWidgetConfig(id, oldConfig);
        applyScale(oldScale);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.updateBoardWidgetConfig(id, newConfig);
        if (newScale != null) applyScale(newScale);
      },
    ));
  }

  void onMoveWidgetToTop(String id) {
    final boardId = viewModel.activeSubBoardId;
    final originalIndex = viewModel.boardWidgets.indexWhere((w) => w.id == id);
    if (originalIndex == -1) return;
    final targetIndex = viewModel.boardWidgets.length - 1;
    if (originalIndex == targetIndex) return;
    viewModel.reorderBoardWidget(id, targetIndex);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.reorderBoardWidget(id, originalIndex);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.reorderBoardWidget(id, viewModel.boardWidgets.length - 1);
      },
    ));
  }

  void onMoveWidgetUp(String id) {
    final boardId = viewModel.activeSubBoardId;
    final originalIndex = viewModel.boardWidgets.indexWhere((w) => w.id == id);
    if (originalIndex == -1) return;
    final targetIndex = (originalIndex + 1).clamp(0, viewModel.boardWidgets.length - 1);
    if (originalIndex == targetIndex) return;
    viewModel.reorderBoardWidget(id, targetIndex);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.reorderBoardWidget(id, originalIndex);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        final idx = viewModel.boardWidgets.indexWhere((w) => w.id == id);
        viewModel.reorderBoardWidget(id, (idx + 1).clamp(0, viewModel.boardWidgets.length - 1));
      },
    ));
  }

  void onMoveWidgetDown(String id) {
    final boardId = viewModel.activeSubBoardId;
    final originalIndex = viewModel.boardWidgets.indexWhere((w) => w.id == id);
    if (originalIndex == -1) return;
    final targetIndex = (originalIndex - 1).clamp(0, viewModel.boardWidgets.length - 1);
    if (originalIndex == targetIndex) return;
    viewModel.reorderBoardWidget(id, targetIndex);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.reorderBoardWidget(id, originalIndex);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        final idx = viewModel.boardWidgets.indexWhere((w) => w.id == id);
        viewModel.reorderBoardWidget(id, (idx - 1).clamp(0, viewModel.boardWidgets.length - 1));
      },
    ));
  }

  void onMoveWidgetToBottom(String id) {
    final boardId = viewModel.activeSubBoardId;
    final originalIndex = viewModel.boardWidgets.indexWhere((w) => w.id == id);
    if (originalIndex == -1 || originalIndex == 0) return;
    viewModel.reorderBoardWidget(id, 0);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.reorderBoardWidget(id, originalIndex);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.reorderBoardWidget(id, 0);
      },
    ));
  }

  // Widget transform history callbacks (called by Board)

  void onWidgetTransformStart(String id) {
    _transformBoardId = viewModel.activeSubBoardId;
    _transformBefore = {
      for (final bw in viewModel.boardWidgets)
        if (bw.id == id) bw.id: (bw.x, bw.y, bw.rotation, bw.scale),
    };
  }

  void onWidgetTransformEnd(String id) {
    final before = _transformBefore;
    final boardId = _transformBoardId;
    _transformBefore = null;
    _transformBoardId = null;
    if (before == null || boardId == null) return;
    final after = {
      for (final bw in viewModel.boardWidgets)
        if (before.containsKey(bw.id)) bw.id: (bw.x, bw.y, bw.rotation, bw.scale),
    };
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        for (final e in before.entries) {
          viewModel.updateBoardWidget(e.key, e.value.$1, e.value.$2, e.value.$3, e.value.$4);
        }
      },
      redo: () {
        _ensureActiveBoard(boardId);
        for (final e in after.entries) {
          viewModel.updateBoardWidget(e.key, e.value.$1, e.value.$2, e.value.$3, e.value.$4);
        }
      },
    ));
  }

  // Board settings handler

  /// Opens the board-settings dialog, which edits a working copy of the active
  /// board's appearance with a live preview. The real board is left untouched
  /// until the user confirms (or picks a board to copy from); the whole edit
  /// then lands as a single undoable change.
  Future<void> onShowBoardSettings() async {
    final context = contextAccessor.buildContext;
    final boardId = viewModel.activeSubBoardId;
    final before = viewModel.board;
    final result = await showDialog<Board>(
      context: context,
      builder: (_) => BoardSettingsDialog(
        board: before,
        otherBoards: viewModel.subBoards.where((b) => b.id != boardId).toList(),
        apiClient: _wsClient,
        fileService: _fileService,
        boardPixelRatio: viewModel.boardPixelRatio,
      ),
      barrierDismissible: true,
    );
    // null = dismissed/cancelled, leaving the board as it was.
    if (result == null || _sameAppearance(before, result)) return;
    viewModel.setBoardAppearance(result);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.setBoardAppearance(before);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.setBoardAppearance(result);
      },
    ));
  }

  bool _sameAppearance(Board a, Board b) =>
      a.backgroundColor == b.backgroundColor &&
      a.isChalkboard == b.isChalkboard &&
      a.linePattern == b.linePattern &&
      a.lineSpacing == b.lineSpacing &&
      a.lineColor == b.lineColor &&
      a.backgroundFileId == b.backgroundFileId;

  void _ensureActiveBoard(String boardId) {
    if (viewModel.activeSubBoardId != boardId) onSwitchSubBoard(boardId);
  }

  // Drawing restore helper

  List<PaintContent> _restoreDrawingContents(List<Map<String, dynamic>> jsonList) {
    return jsonList.map((json) {
      return switch (json['type'] as String?) {
        'SimpleLine' => SimpleLine.fromJson(json),
        'SmoothLine' => SmoothLine.fromJson(json),
        'StraightLine' => StraightLine.fromJson(json),
        'Rectangle' => Rectangle.fromJson(json),
        'Circle' => Circle.fromJson(json),
        'Eraser' => Eraser.fromJson(json),
        _ => null,
      };
    }).whereType<PaintContent>().toList();
  }

}
