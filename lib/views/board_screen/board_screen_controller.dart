import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';

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
    viewModel.setActiveColor(value);
    drawingController.setStyle(color: value);
  }

}
