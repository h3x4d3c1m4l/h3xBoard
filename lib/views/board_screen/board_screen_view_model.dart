import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/drawing_tools.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'board_screen_view_model.g.dart';

class BoardScreenViewModel = BoardScreenViewModelBase with _$BoardScreenViewModel;

abstract class BoardScreenViewModelBase extends ScreenViewModelBase with Store {

  @readonly
  Board _board = Board(
    title: 'Board of ${DateTime.now()}',
    backgroundColor: Colors.white,
    isChalkboard: false,
    linePattern: BoardLinePattern.none,
    lineSpacing: 64,
    lineColor: Colors.grey[100],
  );

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

  @readonly
  ObservableSet<String> _selectedWidgetIds = ObservableSet();

  @readonly
  bool _isFullscreen = false;

  BoardScreenViewModelBase({
    required super.contextAccessor,
  });

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
    _board = _board.copyWith(backgroundColor: color, isChalkboard: isChalkboard);
  }

  @action
  void setBoardLineColor(Color color) {
    _board = _board.copyWith(lineColor: color);
  }

  @action
  void setBoardLinePattern(BoardLinePattern pattern) {
    _board = _board.copyWith(linePattern: pattern);
  }

  @action
  void setBoardLineSpacing(double spacing) {
    _board = _board.copyWith(lineSpacing: spacing);
  }

  @action
  void setFullscreen(bool value) {
    _isFullscreen = value;
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
  void selectWidget(String id, {bool multiSelect = false}) {
    if (multiSelect) {
      if (_selectedWidgetIds.contains(id)) {
        _selectedWidgetIds.remove(id);
      } else {
        _selectedWidgetIds.add(id);
      }
    } else {
      _selectedWidgetIds = ObservableSet.of([id]);
    }
  }

  @action
  void clearSelection() => _selectedWidgetIds.clear();

  @action
  void updateBoardWidgetConfig(String id, BoardWidgetConfig config) {
    final index = _boardWidgets.indexWhere((w) => w.id == id);
    if (index != -1) {
      _boardWidgets[index] = _boardWidgets[index].copyWith(config: config);
    }
  }

  @action
  void removeBoardWidget(String id) {
    _boardWidgets.removeWhere((w) => w.id == id);
    _selectedWidgetIds.remove(id);
  }

  @action
  void reorderBoardWidget(String id, int newIndex) {
    final index = _boardWidgets.indexWhere((w) => w.id == id);
    if (index == -1) return;
    final widget = _boardWidgets.removeAt(index);
    _boardWidgets.insert(newIndex.clamp(0, _boardWidgets.length), widget);
  }

}
