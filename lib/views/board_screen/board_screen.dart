import 'package:auto_route/annotations.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';

@RoutePage()
class BoardScreen extends ScreenBase<BoardScreenViewModel, BoardScreenController, BoardScreenView> {

  final String boardId;

  const BoardScreen({super.key, @pathParam required this.boardId});

  @override
  BoardScreenController createController({required BoardScreenViewModel viewModel, required BuildContextAccessor contextAccessor}) {
    return BoardScreenController(boardId: boardId, viewModel: viewModel, contextAccessor: contextAccessor);
  }

  @override
  BoardScreenView createView({required BoardScreenController controller, required BoardScreenViewModel viewModel, required BuildContextAccessor contextAccessor}) {
    return BoardScreenView(viewModel: viewModel, controller: controller, contextAccessor: contextAccessor);
  }

  @override
  BoardScreenViewModel createViewModel({required BuildContextAccessor contextAccessor}) {
    return BoardScreenViewModel(contextAccessor: contextAccessor);
  }

}
