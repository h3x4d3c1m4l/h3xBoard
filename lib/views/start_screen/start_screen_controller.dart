import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/app_router.gr.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/board_summary.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/start_screen/start_screen_view_model.dart';

// Matches 'Board N' titles to pick the next auto-number for a new board.
final _boardTitleRegex = RegExp(r'^Board (\d+)$');

class StartScreenController extends ScreenControllerBase<StartScreenViewModel> {

  final _wsClient = GetIt.I<H3xBoardApiClient>();
  final _auth = GetIt.I<H3xBoardAuthService>();
  final _session = GetIt.I<SessionController>();

  StartScreenController({
    required super.viewModel,
    required super.contextAccessor,
  }) {
    // Defer until after the first frame so the BuildContext is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => loadBoards());
  }

  Future<void> loadBoards() async {
    viewModel
      ..setIsLoading(true)
      ..setErrorMessage(null);
    try {
      final boards = await _wsClient.listBoards();
      viewModel.setBoards(boards);
    } on H3xBoardApiException catch (e) {
      viewModel.setErrorMessage(e.message);
    } catch (e) {
      viewModel.setErrorMessage(e.toString());
    } finally {
      viewModel.setIsLoading(false);
    }
  }

  Future<void> openBoard(BoardSummary board) async {
    await contextAccessor.buildContext.pushRoute(BoardRoute());
  }

  Future<void> onCreateBoardPressed() async {
    viewModel
      ..setIsLoading(true)
      ..setErrorMessage(null);
    try {
      await _wsClient.createBoard(title: _nextBoardTitle());
      final boards = await _wsClient.listBoards();
      viewModel.setBoards(boards);
    } on H3xBoardApiException catch (e) {
      viewModel.setErrorMessage(e.message);
    } catch (e) {
      viewModel.setErrorMessage(e.toString());
    } finally {
      viewModel.setIsLoading(false);
    }
  }

  /// Picks the next free 'Board N' title from the boards already loaded.
  String _nextBoardTitle() {
    final existingNumbers = viewModel.boards
        .map((b) => _boardTitleRegex.firstMatch(b.title)?.group(1))
        .whereType<String>()
        .map(int.parse)
        .toList();
    final nextNumber = (existingNumbers.isEmpty ? 0 : existingNumbers.reduce((a, b) => a > b ? a : b)) + 1;
    return 'Board $nextNumber';
  }

  Future<void> onLogoutPressed() async {
    try {
      await _auth.logout();
    } catch (_) {}
    try {
      await _wsClient.disconnect();
    } catch (_) {}
    _session.markUnauthenticated();
    // Navigate explicitly rather than leaning on the guard's reevaluate
    // redirect, which is unreliable while a deep-link route is still pending.
    if (contextAccessor.buildContext.mounted) {
      await contextAccessor.buildContext.router.replaceAll([LoginRoute()]);
    }
  }

}
