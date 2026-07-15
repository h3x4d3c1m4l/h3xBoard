import 'package:auto_route/annotations.dart';
import 'package:h3xboard/models/api/board_detail.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';

@RoutePage()
class BoardScreen extends ScreenBase<BoardScreenViewModel, BoardScreenController, BoardScreenView> {

  final String boardId;

  /// The already-fetched board, handed in when the boards overview loaded it
  /// before navigating (so this screen paints immediately without a second
  /// spinner). Null when the board is entered directly (deep link / web reload),
  /// in which case the screen loads it itself. Not part of the route path, so it
  /// is naturally absent on a cold URL load.
  final BoardDetail? preloadedDetail;

  const BoardScreen({super.key, @pathParam required this.boardId, this.preloadedDetail});

  @override
  BoardScreenController createController({required BoardScreenViewModel viewModel, required BuildContextAccessor contextAccessor}) {
    return BoardScreenController(
      boardId: boardId,
      preloadedDetail: preloadedDetail,
      viewModel: viewModel,
      contextAccessor: contextAccessor,
    );
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
