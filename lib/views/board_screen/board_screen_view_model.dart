import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_content.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/drawing_tools.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'board_screen_view_model.g.dart';

enum BoardSaveStatus { idle, saving, saved, error }

/// A blank starter board, used both as the initial state and when a board is
/// opened that has no persisted sub-boards yet.
Board _defaultBoard() => Board(
  id: 'board_1',
  title: 'Board 1',
  backgroundColor: Colors.white,
  isChalkboard: false,
  linePattern: BoardLinePattern.none,
  lineSpacing: 64,
  lineColor: Colors.grey[100],
);

class BoardScreenViewModel = BoardScreenViewModelBase with _$BoardScreenViewModel;

abstract class BoardScreenViewModelBase extends ScreenViewModelBase with Store {

  @readonly
  ObservableList<Board> _subBoards = ObservableList.of([_defaultBoard()]);

  @readonly
  String _activeSubBoardId = 'board_1';

  @readonly
  bool _isLoading = true;

  @readonly
  String? _loadError;

  @readonly
  BoardSaveStatus _saveStatus = BoardSaveStatus.idle;

  @readonly
  ObservableMap<String, List<Map<String, dynamic>>> _subBoardDrawings = ObservableMap();

  @readonly
  DrawingTools _drawingTools = DrawingTools(
    activeColor: Colors.black,
    lastActiveColor: Colors.black,
    activeTool: .pen,
    penWidth: 2,
    eraserWidth: 8,
  );

  @readonly
  double _boardPixelRatio = 1;

  @readonly
  ObservableList<BoardWidget> _boardWidgets = ObservableList();

  // The single widget currently in Arrange mode (resize/rotate handles shown,
  // body dimmed & paused). null = no widget is being arranged.
  @readonly
  String? _arrangingWidgetId;

  @readonly
  bool _isFullscreen = false;

  @computed
  Board get board => _subBoards.firstWhere(
    (b) => b.id == _activeSubBoardId,
    orElse: () => _subBoards.first,
  );

  @computed
  List<BoardWidget> get visibleBoardWidgets => _boardWidgets
      .where((w) => w.isVisibleOnAllBoards || w.visibleOnBoardIds.contains(_activeSubBoardId))
      .toList();

  BoardScreenViewModelBase({
    required super.contextAccessor,
  });

  @action
  void setIsLoading(bool value) {
    _isLoading = value;
  }

  @action
  void setLoadError(String? value) {
    _loadError = value;
  }

  @action
  void setSaveStatus(BoardSaveStatus value) {
    _saveStatus = value;
  }

  /// Replaces the entire board state with the persisted [content]. Falls back to
  /// a single blank board when nothing has been saved yet.
  @action
  void setInitialContent(BoardContent content) {
    final boards = content.subBoards.isEmpty ? [_defaultBoard()] : content.subBoards;
    _subBoards = ObservableList.of(boards);
    _boardWidgets = ObservableList.of(content.widgets);
    _subBoardDrawings = ObservableMap.of(content.drawings);
    _arrangingWidgetId = null;
    _activeSubBoardId = boards.any((b) => b.id == content.activeSubBoardId)
        ? content.activeSubBoardId
        : boards.first.id;
    resyncMatchedWidgets();
  }

  @action
  void setActiveColor(Color? color) {
    _drawingTools = _drawingTools.copyWith(
      activeColor: color,
      lastActiveColor: color ?? _drawingTools.lastActiveColor,
    );
  }

  @action
  void setActiveTool(SelectableEditTool tool) {
    final current = _drawingTools.activeTool;
    _drawingTools = _drawingTools.copyWith(
      activeTool: tool,
      lastActiveTool: (current == .pen || current == .eraser) ? current : _drawingTools.lastActiveTool,
    );
  }

  @action
  void setPenWidth(double width) {
    _drawingTools = _drawingTools.copyWith(penWidth: width);
  }

  @action
  void setEraserWidth(double width) {
    _drawingTools = _drawingTools.copyWith(eraserWidth: width);
  }

  @action
  void updateResizeFactor(BoxConstraints constaints) {
    double heightFactor = 1080 / constaints.maxHeight;
    double widthFactor = 1920 / constaints.maxWidth;

    double resize;
    if (heightFactor > widthFactor) {
      resize = heightFactor;
    } else {
      resize = widthFactor;
    }

    _boardPixelRatio = resize;
  }

  @action
  void setBoardColorAndType(Color color, bool isChalkboard) {
    _updateActiveSubBoard((b) => b.copyWith(backgroundColor: color, isChalkboard: isChalkboard));
  }

  @action
  void setBoardBackgroundFileId(String? fileId) {
    _updateActiveSubBoard((b) => b.copyWith(backgroundFileId: fileId));
  }

  @action
  void setBoardLineColor(Color color) {
    _updateActiveSubBoard((b) => b.copyWith(lineColor: color));
  }

  @action
  void setBoardLinePattern(BoardLinePattern pattern) {
    _updateActiveSubBoard((b) => b.copyWith(linePattern: pattern));
  }

  @action
  void setBoardLineSpacing(double spacing) {
    _updateActiveSubBoard((b) => b.copyWith(lineSpacing: spacing));
    resyncMatchedWidgets();
  }

  /// Replaces every appearance field of the active sub-board at once (its id and
  /// title are kept). Used by the board-settings dialog, which edits a working
  /// copy and commits the whole result as a single change.
  @action
  void setBoardAppearance(Board appearance) {
    _updateActiveSubBoard((b) => b.copyWith(
      backgroundColor: appearance.backgroundColor,
      isChalkboard: appearance.isChalkboard,
      linePattern: appearance.linePattern,
      lineSpacing: appearance.lineSpacing,
      lineColor: appearance.lineColor,
      backgroundFileId: appearance.backgroundFileId,
    ));
    resyncMatchedWidgets();
  }

  // Re-derives the scale of every grid-matched widget (ruler, geodreieck) from the
  // current grid spacing so matched widgets track the grid-spacing slider (and
  // undo/redo of it) live. Matched scale is a pure function of (config, lineSpacing),
  // so no extra history bookkeeping is needed — replaying the spacing change replays
  // the scale.
  @action
  void resyncMatchedWidgets() {
    final spacing = board.lineSpacing;
    for (var i = 0; i < _boardWidgets.length; i++) {
      final bw = _boardWidgets[i];
      final s = boardWidgetMatchScale(bw.config, spacing);
      if (s != null && bw.scale != s) _boardWidgets[i] = bw.copyWith(scale: s);
    }
  }

  @action
  void setFullscreen(bool value) {
    _isFullscreen = value;
  }

  @action
  void addSubBoard(Board subBoard) {
    _subBoards.add(subBoard);
  }

  @action
  void removeSubBoard(String id) {
    _subBoards.removeWhere((b) => b.id == id);
    _subBoardDrawings.remove(id);
    _boardWidgets.removeWhere((w) {
      if (w.isVisibleOnAllBoards) return false;
      final remaining = w.visibleOnBoardIds.where((bid) => bid != id).toList();
      return remaining.isEmpty;
    });
    _boardWidgets
        .where((w) => !w.isVisibleOnAllBoards && w.visibleOnBoardIds.contains(id))
        .toList()
        .forEach((w) {
      final idx = _boardWidgets.indexWhere((bw) => bw.id == w.id);
      if (idx != -1) {
        _boardWidgets[idx] = w.copyWith(
          visibleOnBoardIds: w.visibleOnBoardIds.where((bid) => bid != id).toList(),
        );
      }
    });
  }

  @action
  void renameSubBoard(String id, String title) {
    final index = _subBoards.indexWhere((b) => b.id == id);
    if (index != -1) {
      _subBoards[index] = _subBoards[index].copyWith(title: title);
    }
  }

  @action
  void setActiveSubBoardId(String id) {
    _activeSubBoardId = id;
    _arrangingWidgetId = null;
  }

  @action
  void saveSubBoardDrawing(String id, List<Map<String, dynamic>> data) {
    _subBoardDrawings[id] = data;
  }

  @action
  void addBoardWidget(BoardWidget widget) {
    _boardWidgets.add(widget);
  }

  @action
  void updateBoardWidget(String id, double x, double y, double rotation, double scale) {
    final index = _boardWidgets.indexWhere((w) => w.id == id);
    if (index != -1) {
      _boardWidgets[index] = _boardWidgets[index].copyWith(x: x, y: y, rotation: rotation, scale: scale);
    }
  }

  @action
  void setArrangingWidget(String? id) => _arrangingWidgetId = id;

  @action
  void updateBoardWidgetConfig(String id, BoardWidgetConfig config) {
    final index = _boardWidgets.indexWhere((w) => w.id == id);
    if (index != -1) {
      _boardWidgets[index] = _boardWidgets[index].copyWith(config: config);
    }
  }

  @action
  void updateBoardWidgetVisibility(String id, bool isVisibleOnAllBoards, List<String> boardIds) {
    final index = _boardWidgets.indexWhere((w) => w.id == id);
    if (index != -1) {
      _boardWidgets[index] = _boardWidgets[index].copyWith(
        isVisibleOnAllBoards: isVisibleOnAllBoards,
        visibleOnBoardIds: boardIds,
      );
    }
  }

  @action
  void removeBoardWidget(String id) {
    _boardWidgets.removeWhere((w) => w.id == id);
    if (_arrangingWidgetId == id) _arrangingWidgetId = null;
  }

  @action
  void reorderBoardWidget(String id, int newIndex) {
    final index = _boardWidgets.indexWhere((w) => w.id == id);
    if (index == -1) return;
    final widget = _boardWidgets.removeAt(index);
    _boardWidgets.insert(newIndex.clamp(0, _boardWidgets.length), widget);
  }

  void _updateActiveSubBoard(Board Function(Board) update) {
    final index = _subBoards.indexWhere((b) => b.id == _activeSubBoardId);
    if (index != -1) {
      _subBoards[index] = update(_subBoards[index]);
    }
  }

  List<Map<String, dynamic>> restoreSubBoardDrawing(String id) {
    return _subBoardDrawings[id] ?? [];
  }

}
