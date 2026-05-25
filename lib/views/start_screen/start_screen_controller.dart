import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/app_router.gr.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/board_summary.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/start_screen/start_screen_view_model.dart';

class StartScreenController extends ScreenControllerBase<StartScreenViewModel> {

  final _client = GetIt.I<H3xBoardApiClient>();

  StartScreenController({
    required super.viewModel,
    required super.contextAccessor,
  }) {
    // Defer until after the first frame so the BuildContext is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => loadBoards());
  }

  Future<void> loadBoards() async {
    final router = contextAccessor.buildContext.router;
    viewModel
      ..setIsLoading(true)
      ..setErrorMessage(null);
    try {
      final boards = await _client.listBoards();
      viewModel.setBoards(boards);
    } on H3xBoardApiException catch (e) {
      if (e.isUnauthenticated) {
        await router.replace(LoginRoute());
      } else {
        viewModel.setErrorMessage(e.message);
      }
    } catch (e) {
      viewModel.setErrorMessage(e.toString());
    } finally {
      viewModel.setIsLoading(false);
    }
  }

  Future<void> openBoard(BoardSummary board) async {
    await contextAccessor.buildContext.pushRoute(BoardRoute());
  }

  Future<void> logout() async {
    final router = contextAccessor.buildContext.router;
    try {
      await _client.logout();
    } catch (_) {}
    await router.replace(LoginRoute());
  }

}
