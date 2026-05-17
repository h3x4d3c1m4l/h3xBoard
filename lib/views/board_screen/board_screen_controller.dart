import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/drawing_tools.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';

class BoardScreenController extends ScreenControllerBase<BoardScreenViewModel> {

  final DrawingController drawingController = DrawingController();

  // Initialization/Deinitialization

  BoardScreenController({
    required super.viewModel,
    required super.contextAccessor,
  }) {
    drawingController.setStyle(color: viewModel.drawingTools.activeColor);
    viewModel
      ..addBoardWidget(const BoardWidget(id: 'clock_1', config: ClockConfig(), x: 200, y: 400, scale: 1.5, rotation: 0.25 * pi))
      ..addBoardWidget(const BoardWidget(id: 'traffic_1', config: TrafficLightConfig(), x: 960, y: 540));
  }

  @override
  void dispose() {
    super.dispose();
    drawingController.dispose();
  }

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

  void onClearButtonPressed() {
    drawingController.clear();
  }

  void onPenWidthSliderMoved(double value) {
    drawingController.setStyle(strokeWidth: value);
    viewModel.setPenWidth(value);
  }

  void onEraserWidthSliderMoved(double value) {
    drawingController.setStyle(strokeWidth: value);
    viewModel.setEraserWidth(value);
  }

  void onBoardBackgroundColorPicked(Color color, bool isChalkboard) {
    viewModel.setBoardColorAndType(color, isChalkboard);
  }

  void onBoardLinePatternPicked(BoardLinePattern pattern) {
    viewModel.setBoardLinePattern(pattern);
  }

  void onBoardLineSpacingSliderMoved(double value) {
    viewModel.setBoardLineSpacing(value);
  }

  void onBoardLineColorPicked(Color color) {
    viewModel.setBoardLineColor(color);
  }

}
