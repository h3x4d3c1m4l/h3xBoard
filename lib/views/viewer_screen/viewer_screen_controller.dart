import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/board_asset_resolver.dart';
import 'package:h3xboard/services/live_share/live_view_client.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/viewer_screen/viewer_screen_view_model.dart';

class ViewerScreenController extends ScreenControllerBase<ViewerScreenViewModel> {

  /// Streams the shared board; null while the code-entry UI is shown.
  LiveViewClient? client;

  /// Resolves image/background bytes through the anonymous share-code file
  /// endpoint; non-null exactly when [client] is.
  ViewCodeBoardAssetResolver? assetResolver;

  ViewerScreenController({
    required String? initialCode,
    required super.viewModel,
    required super.contextAccessor,
  }) {
    final code = normalizeCode(initialCode ?? '');
    if (code.isEmpty) return;
    final serverUrl = GetIt.I<ServerController>().serverUrl;
    client = LiveViewClient(serverUrl: serverUrl, code: code);
    assetResolver = ViewCodeBoardAssetResolver(serverUrl: serverUrl, code: code);
    unawaited(client!.start());
  }

  /// Codes are entered/displayed with grouping dashes and in any case;
  /// normalize to the canonical form the server generates.
  static String normalizeCode(String raw) => raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  /// Opens the viewer for the entered code by re-navigating this route with
  /// the code as its path parameter (so the flow matches a share link).
  void onSubmitCode() {
    final code = normalizeCode(viewModel.codeController.text);
    if (code.isEmpty) return;
    unawaited(contextAccessor.buildContext.router.replace(ViewerRoute(code: code)));
  }

  /// Back to the empty code-entry UI (e.g. after a session ended).
  void onWatchAnother() {
    unawaited(contextAccessor.buildContext.router.replace(const ViewerEntryRoute()));
  }

  /// Leaves the viewer: signed-in users return to their boards, anonymous
  /// viewers to the login screen.
  void onLeave() {
    final router = contextAccessor.buildContext.router;
    if (GetIt.I<SessionController>().isAuthenticated) {
      unawaited(router.replaceAll([const BoardsRoute()]));
    } else {
      unawaited(router.replaceAll([LoginRoute()]));
    }
  }

  /// The receiver spotted a sequence gap — ask for a fresh snapshot.
  void onGapDetected() => client?.requestResync();

  @override
  void dispose() {
    client?.dispose();
    assetResolver?.dispose();
    super.dispose();
  }

}
