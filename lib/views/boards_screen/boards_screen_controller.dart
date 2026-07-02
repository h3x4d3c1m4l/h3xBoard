import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/app_router.gr.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/board_summary.dart';
import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/boards_screen/boards_screen_view_model.dart';

// Matches 'Board N' titles to pick the next auto-number for a new board.
final _boardTitleRegex = RegExp(r'^Board (\d+)$');

class BoardsScreenController extends ScreenControllerBase<BoardsScreenViewModel> {

  final _wsClient = GetIt.I<H3xBoardApiClient>();
  final _auth = GetIt.I<H3xBoardAuthService>();
  final _session = GetIt.I<SessionController>();
  final _cookieStore = GetIt.I<CookieStore>();

  BoardsScreenController({
    required super.viewModel,
    required super.contextAccessor,
  }) {
    // Defer until after the first frame so the BuildContext is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => loadBoards());
  }

  /// The signed-in user's first name, or `null` when unknown (registration makes
  /// it optional). Used only to personalise the greeting.
  String? get firstName {
    final name = _session.firstName?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  /// A label for the account chip: the full name when we have one, otherwise the
  /// email.
  String get userDisplayName {
    final parts = [_session.firstName, _session.lastName]
        .map((p) => p?.trim())
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(' ');
    return _session.email ?? '';
  }

  /// One or two initials for the account avatar, derived from the name, falling
  /// back to the first letter of the email.
  String get userInitials {
    final first = _session.firstName?.trim();
    final last = _session.lastName?.trim();
    final letters = [first, last]
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .join();
    if (letters.isNotEmpty) return letters;
    final email = _session.email?.trim();
    return (email != null && email.isNotEmpty) ? email[0].toUpperCase() : '?';
  }

  /// Loads the board list. [showSpinner] is false for a silent refresh (e.g. when
  /// returning from a board) so the grid doesn't flash a full-screen spinner.
  Future<void> loadBoards({bool showSpinner = true}) async {
    if (showSpinner) viewModel.setIsLoading(true);
    viewModel.setErrorMessage(null);
    try {
      final boards = await _wsClient.listBoards();
      viewModel
        ..setBoards(boards)
        // Nudge thumbnails to re-fetch — a board's screenshot may have changed
        // (e.g. we just came back from editing it) without any summary field.
        ..bumpReloadTick();
    } on H3xBoardApiException catch (e) {
      viewModel.setErrorMessage(e.message);
    } catch (e) {
      viewModel.setErrorMessage(e.toString());
    } finally {
      if (showSpinner) viewModel.setIsLoading(false);
    }
  }

  void onSearchChanged(String query) => viewModel.setSearchQuery(query);

  Future<void> openBoard(BoardSummary board) async {
    await contextAccessor.buildContext.pushRoute(BoardRoute(boardId: board.id));
    // Refresh quietly on return so edited titles/timestamps (and, over time, new
    // thumbnails) show up without a jarring spinner.
    await loadBoards(showSpinner: false);
  }

  Future<void> onDeleteBoard(BoardSummary board) async {
    viewModel
      ..setIsLoading(true)
      ..setErrorMessage(null);
    try {
      await _wsClient.deleteBoard(board.id);
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

  /// Creates a fresh board and opens it straight away (the "New blank board"
  /// flow). On return, the list is refreshed so the new board appears.
  Future<void> onCreateBoardPressed() async {
    viewModel
      ..setIsLoading(true)
      ..setErrorMessage(null);
    try {
      final board = await _wsClient.createBoard(title: _nextBoardTitle());
      viewModel.setIsLoading(false);
      final context = contextAccessor.buildContext;
      if (context.mounted) {
        await context.pushRoute(BoardRoute(boardId: board.id));
      }
      await loadBoards(showSpinner: false);
    } on H3xBoardApiException catch (e) {
      viewModel
        ..setErrorMessage(e.message)
        ..setIsLoading(false);
    } catch (e) {
      viewModel
        ..setErrorMessage(e.toString())
        ..setIsLoading(false);
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
    try {
      await _cookieStore.clear();
    } catch (_) {}
    _session.markUnauthenticated();
    // Navigate explicitly rather than leaning on the guard's reevaluate
    // redirect, which is unreliable while a deep-link route is still pending.
    if (contextAccessor.buildContext.mounted) {
      await contextAccessor.buildContext.router.replaceAll([LoginRoute()]);
    }
  }

}
