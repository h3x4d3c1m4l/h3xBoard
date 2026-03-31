import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/board.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/drawing_toolbar.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/tool_toolbar.dart';

class BoardScreenView extends ScreenViewBase<BoardScreenViewModel, BoardScreenController> {
  const BoardScreenView({required super.viewModel, required super.controller, required super.contextAccessor});

  @override
  Widget get body {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        spacing: 8,
        children: [
          ToolToolbar(controller: controller, viewModel: viewModel),
          Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 8,
              children: [
                Observer(
                  builder: (_) => DrawingToolbar(
                    activeColor: viewModel.activeDrawingColor,
                    onColorButtonPressed: controller.onColorButtonPressed,
                  ),
                ),
                Flexible(child: LayoutBuilder(
                  builder: (context, constraints) {
                    viewModel.updateResizeFactor(constraints);
                    return Board(drawingController: controller.drawingController, viewModel: viewModel);
                  }
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
