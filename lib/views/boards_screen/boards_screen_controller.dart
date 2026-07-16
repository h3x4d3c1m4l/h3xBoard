import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/board_detail.dart';
import 'package:h3xboard/models/api/board_summary.dart';
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/boards_screen/boards_screen_view_model.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:h3xboard/views/components/dialogs/themable_loading_dialog.dart';

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
    // Fetch the board here, behind a loading dialog, so the board screen opens
    // already-loaded (mirroring how leaving a board shows a save dialog first).
    final detail = await _fetchBoardForOpen(board.id);
    if (detail == null) return; // load failed and the user backed out
    final context = contextAccessor.buildContext;
    if (!context.mounted) return;
    await context.pushRoute(BoardRoute(boardId: board.id, preloadedDetail: detail));
    // Refresh quietly on return so edited titles/timestamps (and, over time, new
    // thumbnails) show up without a jarring spinner.
    await loadBoards(showSpinner: false);
  }

  /// Fetches a board while showing the modal loading dialog, retrying via an
  /// error dialog on failure. Returns the loaded board, or `null` if the user
  /// gave up. Mirrors [BoardScreenController]'s close/save dialog structure.
  Future<BoardDetail?> _fetchBoardForOpen(String boardId) async {
    while (true) {
      final context = contextAccessor.buildContext;
      if (!context.mounted) return null;

      // Capture the navigator before showing the dialog rather than relying on
      // the builder's context: showDialog pushes the route synchronously, but
      // the builder only runs on the next frame. A fast failure (e.g. the
      // socket is already down) can resolve before that frame, leaving the
      // dialog un-poppable and stacking on every retry.
      final navigator = Navigator.of(context, rootNavigator: true);
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ThemableLoadingDialog(message: localizations.boardsScreen_openingBoard),
      ));

      BoardDetail? detail;
      try {
        detail = await _wsClient.getBoard(boardId);
      } catch (_) {
        detail = null;
      }

      if (context.mounted) navigator.pop();

      if (detail != null) return detail;
      if (!await _confirmRetryOpen()) return null;
    }
  }

  /// Shows the board-open failure dialog (Retry / Cancel). Returns `true` to try
  /// the load again, `false` to stay on the boards overview.
  Future<bool> _confirmRetryOpen() async {
    final context = contextAccessor.buildContext;
    if (!context.mounted) return false;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ThemableContentDialog(
        severity: ThemableDialogSeverity.error,
        title: Text(localizations.boardsScreen_openErrorTitle),
        content: Text(localizations.boardsScreen_openErrorMessage),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(localizations.boardsScreen_openErrorCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(localizations.boardsScreen_retry),
          ),
        ],
      ),
    );
    return retry ?? false;
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

  /// Renames a board to [newTitle], then refreshes the list so the new title and
  /// updated timestamp show up.
  Future<void> onRenameBoard(BoardSummary board, String newTitle) async {
    final title = newTitle.trim();
    if (title.isEmpty || title == board.title) return;
    viewModel
      ..setIsLoading(true)
      ..setErrorMessage(null);
    try {
      await _wsClient.updateBoard(id: board.id, title: title);
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
        // createBoard already returns the full board, so hand it straight to the
        // board screen — no need for it to re-fetch what we just made.
        await context.pushRoute(BoardRoute(boardId: board.id, preloadedDetail: board));
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
