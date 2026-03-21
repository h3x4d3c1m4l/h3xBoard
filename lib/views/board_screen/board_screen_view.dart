import 'package:flutter/widgets.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';

class BoardScreenView extends ScreenViewBase<BoardScreenViewModel, BoardScreenController> {

  const BoardScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    return Text("Hello from BoardScreen!");
  }

}
