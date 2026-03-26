import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:h3xboard/views/board_screen/components/tool_toolbar.dart';
import 'package:mobx/mobx.dart';

part 'board_screen_view_model.g.dart';

class BoardScreenViewModel = BoardScreenViewModelBase with _$BoardScreenViewModel;

abstract class BoardScreenViewModelBase extends ScreenViewModelBase with Store {

  @readonly
  Color? _activeColor = Colors.black;

  @readonly
  Color _lastActiveColor = Colors.black;

  @readonly
  SelectableEditTool _activeTool = .pen;

  @readonly
  double _penWidth = 2;

  @readonly
  double _eraserWidth = 8;

  @readonly
  double _boardPixelRatio = 1;

  BoardScreenViewModelBase({
    required super.contextAccessor,
  });

  @action
  void setActiveColor(Color? color) {
    _activeColor = color;
    if (color != null) _lastActiveColor = color;
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

}
