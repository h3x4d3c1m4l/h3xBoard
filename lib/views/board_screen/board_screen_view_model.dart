import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/tool_toolbar.dart';
import 'package:mobx/mobx.dart';

part 'board_screen_view_model.g.dart';

class BoardScreenViewModel = BoardScreenViewModelBase with _$BoardScreenViewModel;

enum BoardLines { none, horizontal, grid }

abstract class BoardScreenViewModelBase extends ScreenViewModelBase with Store {

  @readonly
  Color? _activeDrawingColor = Colors.black;

  @readonly
  Color _lastActiveDrawingColor = Colors.black;

  @readonly
  Color _boardColor = Colors.white;

  @readonly
  bool _isChalkboard = false;

  @readonly
  SelectableEditTool _activeTool = .pen;

  @readonly
  double _penWidth = 2;

  @readonly
  double _eraserWidth = 8;

  @readonly
  double _boardPixelRatio = 1;

  @readonly
  BoardLines _boardLines = BoardLines.none;

  @readonly
  double _boardLineDensity = 64;

  @readonly
  Color _boardLinesColor = Colors.grey[100];

  BoardScreenViewModelBase({
    required super.contextAccessor,
  });

  @action
  void setActiveColor(Color? color) {
    _activeDrawingColor = color;
    if (color != null) _lastActiveDrawingColor = color;
  }

  @action
  void setActiveTool(SelectableEditTool tool) => _activeTool = tool;

  @action
  void setPenWidth(double width) => _penWidth = width;

  @action
  void setEraserWidth(double width) => _eraserWidth = width;

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
    _boardColor = color;
    _isChalkboard = isChalkboard;
  }

  @action
  void setBoardLinesColor(Color color) {
    _boardLinesColor = color;
  }

  @action
  void setBoardLines(BoardLines lines) {
    _boardLines = lines;
  }

  @action
  void setBoardLineDensity(double density) {
    _boardLineDensity = density;
  }

}
