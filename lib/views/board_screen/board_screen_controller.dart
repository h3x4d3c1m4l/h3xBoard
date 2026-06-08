import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
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
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/history/history_entry.dart';
import 'package:h3xboard/views/board_screen/history/history_manager.dart';

// Matches 'Board N' titles to pick the next auto-number.
final _boardTitleRegex = RegExp(r'^Board (\d+)$');

// How long to wait after the last change before persisting the board.
const _autosaveDebounce = Duration(seconds: 1);

class BoardScreenController extends ScreenControllerBase<BoardScreenViewModel> {

  final String boardId;

  final DrawingController drawingController = DrawingController();
  final HistoryManager historyManager = HistoryManager();
  final ValueNotifier<int> drawStartSignal = ValueNotifier(0);
  final FullscreenService _fullscreenService = FullscreenService();
  final _wsClient = GetIt.I<H3xBoardApiClient>();

  // Pending state captured at gesture/stroke boundaries for history recording.
  List<Map<String, dynamic>>? _drawingBefore;
  Map<String, (double, double, double, double)>? _transformBefore;
  String? _transformBoardId;
  double? _lineSpacingBefore;

  // Autosave bookkeeping.
  Timer? _saveTimer;
  bool _saveInFlight = false;
  bool _saveDirty = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBoard());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Flush a final save while the drawing controller is still alive.
    if (_saveDirty && !_saveInFlight) {
      unawaited(_wsClient.updateBoard(id: boardId, data: _buildContent().toJson()));
    }
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
    _saveTimer?.cancel();
    _saveTimer = Timer(_autosaveDebounce, () => unawaited(_save()));
  }

  Future<void> _save() async {
    if (_saveInFlight) return;
    if (!_saveDirty) return;
    _saveDirty = false;
    _saveInFlight = true;
    viewModel.setSaveStatus(BoardSaveStatus.saving);
    try {
      await _wsClient.updateBoard(id: boardId, data: _buildContent().toJson());
      viewModel.setSaveStatus(_saveDirty ? BoardSaveStatus.saving : BoardSaveStatus.saved);
    } catch (_) {
      _saveDirty = true;
      viewModel.setSaveStatus(BoardSaveStatus.error);
    } finally {
      _saveInFlight = false;
      // A change landed mid-save (or the save failed); try again.
      if (_saveDirty) _scheduleSave();
    }
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
      ..clearSelection();
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
        viewModel.clearSelection();
      case .eraser:
        viewModel.setActiveColor(null);
        drawingController.setPaintContent(Eraser());
        drawingController.setStyle(strokeWidth: viewModel.drawingTools.eraserWidth);
        viewModel.clearSelection();
    }

    viewModel.setActiveTool(value);
  }

  void onRestoreDrawingTool() {
    onSelectableToolButtonPressed(viewModel.drawingTools.lastActiveTool);
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

  void onAddWidget(BoardWidgetConfig config) {
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
    final oldConfig = viewModel.boardWidgets.firstWhere((w) => w.id == id).config;
    viewModel.updateBoardWidgetConfig(id, newConfig);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.updateBoardWidgetConfig(id, oldConfig);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.updateBoardWidgetConfig(id, newConfig);
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
    final selectedIds = viewModel.selectedWidgetIds;
    final idsToCapture = selectedIds.contains(id) && selectedIds.length > 1
        ? Set<String>.from(selectedIds)
        : {id};
    _transformBoardId = viewModel.activeSubBoardId;
    _transformBefore = {
      for (final bw in viewModel.boardWidgets)
        if (idsToCapture.contains(bw.id)) bw.id: (bw.x, bw.y, bw.rotation, bw.scale),
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

  // Board settings handlers

  void onBoardBackgroundColorPicked(Color color, bool isChalkboard) {
    final oldBoard = viewModel.board;
    final boardId = viewModel.activeSubBoardId;
    viewModel.setBoardColorAndType(color, isChalkboard);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.setBoardColorAndType(oldBoard.backgroundColor, oldBoard.isChalkboard);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.setBoardColorAndType(color, isChalkboard);
      },
    ));
  }

  void onBoardLinePatternPicked(BoardLinePattern pattern) {
    final oldPattern = viewModel.board.linePattern;
    final boardId = viewModel.activeSubBoardId;
    viewModel.setBoardLinePattern(pattern);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.setBoardLinePattern(oldPattern);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.setBoardLinePattern(pattern);
      },
    ));
  }

  void onBoardLineSpacingSliderMoved(double value) {
    _lineSpacingBefore ??= viewModel.board.lineSpacing;
    viewModel.setBoardLineSpacing(value);
  }

  void onBoardLineSpacingSliderEnd(double value) {
    final before = _lineSpacingBefore;
    _lineSpacingBefore = null;
    if (before == null || before == value) return;
    final boardId = viewModel.activeSubBoardId;
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.setBoardLineSpacing(before);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.setBoardLineSpacing(value);
      },
    ));
  }

  void onBoardLineColorPicked(Color color) {
    final oldColor = viewModel.board.lineColor;
    final boardId = viewModel.activeSubBoardId;
    viewModel.setBoardLineColor(color);
    historyManager.push(HistoryEntry(
      undo: () {
        _ensureActiveBoard(boardId);
        viewModel.setBoardLineColor(oldColor);
      },
      redo: () {
        _ensureActiveBoard(boardId);
        viewModel.setBoardLineColor(color);
      },
    ));
  }

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
