import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/tool_toolbar.dart';

class BoardScreenController extends ScreenControllerBase<BoardScreenViewModel> {

  final DrawingController drawingController = DrawingController();

  // Initialization/Deinitialization

  BoardScreenController({
    required super.viewModel,
    required super.contextAccessor,
  }) {
    drawingController.setStyle(color: viewModel.activeColor);
  }

  @override
  void dispose() {
    super.dispose();
    drawingController.dispose();
  }

  void onColorButtonPressed(Color value) {
    viewModel
      ..setActiveColor(value)
      ..setActiveTool(.pen);
    drawingController
      ..setPaintContent(SimpleLine())
      ..setStyle(color: value);
  }

  void onSelectableToolButtonPressed(SelectableEditTool value) {
    switch (value) {
      case .pen:
        if (viewModel.activeColor == null) {
          viewModel.setActiveColor(viewModel.lastActiveColor);
        }
        drawingController.setPaintContent(SimpleLine());
      case .eraser:
        viewModel.setActiveColor(null);
        drawingController.setPaintContent(Eraser());
    }

    viewModel.setActiveTool(value);
  }

  void onClearButtonPressed() {
    drawingController.clear();
  }
}
