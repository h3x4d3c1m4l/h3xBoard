import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/board.dart';
import 'package:h3xboard/views/board_screen/components/drawing_toolbar.dart';
import 'package:h3xboard/views/board_screen/components/tool_toolbar.dart';

class BoardScreenView extends ScreenViewBase<BoardScreenViewModel, BoardScreenController> {
  const BoardScreenView({required super.viewModel, required super.controller, required super.contextAccessor});

  @override
  Widget get body {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        spacing: 8,
        children: [
          Observer(builder: (_) => ToolToolbar(
            activeTool: viewModel.activeTool,
            onToolButtonPressed: controller.onToolButtonPressed,
          )),
          Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 8,
              children: [
                Observer(
                  builder: (_) => DrawingToolbar(
                    activeColor: viewModel.activeColor,
                    onColorButtonPressed: controller.onColorButtonPressed,
                  ),
                ),
                Flexible(child: Board(drawingController: controller.drawingController)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
