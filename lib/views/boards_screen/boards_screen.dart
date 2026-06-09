import 'package:auto_route/annotations.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_base.dart';
import 'package:h3xboard/views/boards_screen/boards_screen_controller.dart';
import 'package:h3xboard/views/boards_screen/boards_screen_view.dart';
import 'package:h3xboard/views/boards_screen/boards_screen_view_model.dart';

@RoutePage()
class BoardsScreen extends ScreenBase<BoardsScreenViewModel, BoardsScreenController, BoardsScreenView> {

  const BoardsScreen({super.key});

  @override
  BoardsScreenController createController({
    required BoardsScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return BoardsScreenController(viewModel: viewModel, contextAccessor: contextAccessor);
  }

  @override
  BoardsScreenView createView({
    required BoardsScreenController controller,
    required BoardsScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return BoardsScreenView(viewModel: viewModel, controller: controller, contextAccessor: contextAccessor);
  }

  @override
  BoardsScreenViewModel createViewModel({required BuildContextAccessor contextAccessor}) {
    return BoardsScreenViewModel(contextAccessor: contextAccessor);
  }

}
