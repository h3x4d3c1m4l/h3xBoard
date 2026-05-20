import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/drawing_tools.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/history/history_entry.dart';
import 'package:h3xboard/views/board_screen/history/history_manager.dart';

class BoardScreenController extends ScreenControllerBase<BoardScreenViewModel> {

  final DrawingController drawingController = DrawingController();
  final HistoryManager historyManager = HistoryManager();
  final ValueNotifier<int> drawStartSignal = ValueNotifier(0);

  // Pending state captured at gesture/stroke boundaries for history recording.
  List<Map<String, dynamic>>? _drawingBefore;
  Map<String, (double, double, double, double)>? _transformBefore;
  double? _lineSpacingBefore;

  // Initialization/Deinitialization

  BoardScreenController({
    required super.viewModel,
    required super.contextAccessor,
  }) {
    drawingController.setStyle(color: viewModel.drawingTools.activeColor);
  }

  @override
  void dispose() {
    super.dispose();
    drawingController.dispose();
    drawStartSignal.dispose();
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
    historyManager.push(HistoryEntry(
      undo: () {
        drawingController.clear();
        if (before.isNotEmpty) drawingController.addContents(_restoreDrawingContents(before));
      },
      redo: () {
        drawingController.clear();
        if (after.isNotEmpty) drawingController.addContents(_restoreDrawingContents(after));
      },
    ));
  }

  void onClearButtonPressed() {
    final before = drawingController.getJsonList();
    drawingController.clear();
    if (before.isEmpty) return;
    historyManager.push(HistoryEntry(
      undo: () {
        drawingController
          ..clear()
          ..addContents(_restoreDrawingContents(before));
      },
      redo: drawingController.clear,
    ));
  }

  // Widget handlers

  void onAddWidget(BoardWidgetConfig config) {
    final id = '${config.runtimeType}_${DateTime.now().millisecondsSinceEpoch}';
    final widget = BoardWidget(id: id, config: config, x: 960, y: 540);
    viewModel.addBoardWidget(widget);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.removeBoardWidget(id),
      redo: () => viewModel.addBoardWidget(widget),
    ));
  }

  void onDeleteWidget(String id) {
    final widget = viewModel.boardWidgets.firstWhere((w) => w.id == id);
    viewModel.removeBoardWidget(id);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.addBoardWidget(widget),
      redo: () => viewModel.removeBoardWidget(id),
    ));
  }

  void onWidgetConfigChanged(String id, BoardWidgetConfig newConfig) {
    final oldConfig = viewModel.boardWidgets.firstWhere((w) => w.id == id).config;
    viewModel.updateBoardWidgetConfig(id, newConfig);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.updateBoardWidgetConfig(id, oldConfig),
      redo: () => viewModel.updateBoardWidgetConfig(id, newConfig),
    ));
  }

  void onMoveWidgetToTop(String id) {
    final originalIndex = viewModel.boardWidgets.indexWhere((w) => w.id == id);
    if (originalIndex == -1) return;
    final targetIndex = viewModel.boardWidgets.length - 1;
    if (originalIndex == targetIndex) return;
    viewModel.reorderBoardWidget(id, targetIndex);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.reorderBoardWidget(id, originalIndex),
      redo: () => viewModel.reorderBoardWidget(id, viewModel.boardWidgets.length - 1),
    ));
  }

  void onMoveWidgetUp(String id) {
    final originalIndex = viewModel.boardWidgets.indexWhere((w) => w.id == id);
    if (originalIndex == -1) return;
    final targetIndex = (originalIndex + 1).clamp(0, viewModel.boardWidgets.length - 1);
    if (originalIndex == targetIndex) return;
    viewModel.reorderBoardWidget(id, targetIndex);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.reorderBoardWidget(id, originalIndex),
      redo: () {
        final idx = viewModel.boardWidgets.indexWhere((w) => w.id == id);
        viewModel.reorderBoardWidget(id, (idx + 1).clamp(0, viewModel.boardWidgets.length - 1));
      },
    ));
  }

  void onMoveWidgetDown(String id) {
    final originalIndex = viewModel.boardWidgets.indexWhere((w) => w.id == id);
    if (originalIndex == -1) return;
    final targetIndex = (originalIndex - 1).clamp(0, viewModel.boardWidgets.length - 1);
    if (originalIndex == targetIndex) return;
    viewModel.reorderBoardWidget(id, targetIndex);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.reorderBoardWidget(id, originalIndex),
      redo: () {
        final idx = viewModel.boardWidgets.indexWhere((w) => w.id == id);
        viewModel.reorderBoardWidget(id, (idx - 1).clamp(0, viewModel.boardWidgets.length - 1));
      },
    ));
  }

  void onMoveWidgetToBottom(String id) {
    final originalIndex = viewModel.boardWidgets.indexWhere((w) => w.id == id);
    if (originalIndex == -1 || originalIndex == 0) return;
    viewModel.reorderBoardWidget(id, 0);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.reorderBoardWidget(id, originalIndex),
      redo: () => viewModel.reorderBoardWidget(id, 0),
    ));
  }

  // Widget transform history callbacks (called by Board)

  void onWidgetTransformStart(String id) {
    final selectedIds = viewModel.selectedWidgetIds;
    final idsToCapture = selectedIds.contains(id) && selectedIds.length > 1
        ? Set<String>.from(selectedIds)
        : {id};
    _transformBefore = {
      for (final bw in viewModel.boardWidgets)
        if (idsToCapture.contains(bw.id)) bw.id: (bw.x, bw.y, bw.rotation, bw.scale),
    };
  }

  void onWidgetTransformEnd(String id) {
    final before = _transformBefore;
    _transformBefore = null;
    if (before == null) return;
    final after = {
      for (final bw in viewModel.boardWidgets)
        if (before.containsKey(bw.id)) bw.id: (bw.x, bw.y, bw.rotation, bw.scale),
    };
    historyManager.push(HistoryEntry(
      undo: () {
        for (final e in before.entries) {
          viewModel.updateBoardWidget(e.key, e.value.$1, e.value.$2, e.value.$3, e.value.$4);
        }
      },
      redo: () {
        for (final e in after.entries) {
          viewModel.updateBoardWidget(e.key, e.value.$1, e.value.$2, e.value.$3, e.value.$4);
        }
      },
    ));
  }

  // Board settings handlers

  void onBoardBackgroundColorPicked(Color color, bool isChalkboard) {
    final oldBoard = viewModel.board;
    viewModel.setBoardColorAndType(color, isChalkboard);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.setBoardColorAndType(oldBoard.backgroundColor, oldBoard.isChalkboard),
      redo: () => viewModel.setBoardColorAndType(color, isChalkboard),
    ));
  }

  void onBoardLinePatternPicked(BoardLinePattern pattern) {
    final oldPattern = viewModel.board.linePattern;
    viewModel.setBoardLinePattern(pattern);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.setBoardLinePattern(oldPattern),
      redo: () => viewModel.setBoardLinePattern(pattern),
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
    historyManager.push(HistoryEntry(
      undo: () => viewModel.setBoardLineSpacing(before),
      redo: () => viewModel.setBoardLineSpacing(value),
    ));
  }

  void onBoardLineColorPicked(Color color) {
    final oldColor = viewModel.board.lineColor;
    viewModel.setBoardLineColor(color);
    historyManager.push(HistoryEntry(
      undo: () => viewModel.setBoardLineColor(oldColor),
      redo: () => viewModel.setBoardLineColor(color),
    ));
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
