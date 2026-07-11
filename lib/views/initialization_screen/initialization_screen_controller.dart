import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/pending_navigation_service.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/initialization_screen/initialization_screen_view_model.dart';
import 'package:polly_dart/polly_dart.dart';

class InitializationScreenController extends ScreenControllerBase<InitializationScreenViewModel> {

  // Exponential backoff with max 15 seconds wait time and infinite tries.
  static final ResiliencePipeline pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions.infinite(maxDelay: Duration(seconds: 15)))
      .build();

  final ServerController _server = GetIt.I<ServerController>();

  /// The context of the bootstrap run currently in flight. Cancelling it breaks
  /// the (otherwise infinite) retry loop; a run whose context is no longer the
  /// current one is stale and must not touch state or navigate.
  ResilienceContext? _runContext;

  bool _disposed = false;

  InitializationScreenController({
    required super.viewModel,
    required super.contextAccessor,
  }) {
    unawaited(initializeApp());
  }

  /// The API base URL the app is currently pointed at (for the "Server" chip).
  String get serverUrl => _server.serverUrl;

  /// Bootstraps the app, then navigates to Boards (authenticated) or Login (not).
  /// Navigation is driven explicitly via [replaceAll] rather than the guard's
  /// `reevaluateListenable` redirect, which does not fire reliably when a
  /// deep-link route from a web reload is still pending.
  Future<void> initializeApp() async {
    final runContext = ResilienceContext();
    _runContext?.cancel();
    _runContext = runContext;
    try {
      await _bootstrap(runContext);
    } on OperationCancelledException {
      // The server was changed (or the screen went away) mid-run; whoever
      // cancelled us either started a fresh run or tore the screen down.
    }
  }

  /// Re-points the app at [url] and restarts the bootstrap from scratch, so the
  /// session check runs again against the new server (which may well have a
  /// valid cookie of its own).
  Future<void> changeServer(String url) async {
    _runContext?.cancel();
    await _server.setServerUrl(url);
    if (_disposed) return;
    viewModel.resetProgress();
    await initializeApp();
  }

  Future<void> _bootstrap(ResilienceContext runContext) async {
    bool isStale() => _disposed || _runContext != runContext;

    await pipeline.execute(
      (ctx) async {
        _updateProgress(runContext, nowInitializingText: 'Loading fonts ...', retries: ctx.attemptNumber);
        await GoogleFonts.pendingFonts([GoogleFonts.ubuntu(), GoogleFonts.patrickHand()]);
      },
      context: runContext,
    );

    final session = GetIt.I<SessionController>();
    final authService = GetIt.I<H3xBoardAuthService>();
    final wsClient = GetIt.I<H3xBoardApiClient>();

    // whoami() returns null on a 401 (definitively unauthenticated, not retried);
    // a network failure throws and is retried by the pipeline.
    final user = await pipeline.execute(
      (ctx) async {
        _updateProgress(runContext, nowInitializingText: 'Checking session ...', retries: ctx.attemptNumber);
        return authService.whoami();
      },
      context: runContext,
    );

    if (isStale()) return;

    if (user == null) {
      session.markUnauthenticated();
      // Drive navigation explicitly: a web reload funnels here with the original
      // protected route still pending, so relying on the guard's reevaluate +
      // redirectUntil chain leaves us stranded. replaceAll resets the stack.
      await _replaceAll([LoginRoute()]);
      return;
    }

    // Establish the socket before flipping the status, so Boards lands ready.
    await pipeline.execute(
      (ctx) async {
        _updateProgress(runContext, nowInitializingText: 'Connecting to server ...', retries: ctx.attemptNumber);
        await wsClient.connect();
      },
      context: runContext,
    );
    // Pull the user's preferences before the first screen renders so the board
    // lands with the right language and layout. Non-fatal: load() swallows errors.
    await GetIt.I<AppSettingsController>().load();

    if (isStale()) return;

    session.markAuthenticated(
      user.userId,
      user.email,
      firstName: user.firstName,
      lastName: user.lastName,
    );
    final pending = GetIt.I<PendingNavigationService>().consumePendingRoute();
    await _replaceAll([pending ?? const BoardsRoute()]);
  }

  /// Applies progress from [runContext]'s run, ignoring updates from a run that
  /// has since been superseded by a server change.
  void _updateProgress(
    ResilienceContext runContext, {
    required String nowInitializingText,
    required int retries,
  }) {
    if (_disposed || _runContext != runContext) return;
    viewModel.setProgress(nowInitializingText: nowInitializingText, retries: retries);
  }

  /// Resets the navigation stack to [routes], unless the screen is already gone.
  /// Guarded on [_disposed] first: [BuildContextAccessor.buildContext] is only
  /// assigned once the screen has built, so it must not be touched before then.
  Future<void> _replaceAll(List<PageRouteInfo<dynamic>> routes) async {
    if (_disposed || !contextAccessor.buildContext.mounted) return;
    await contextAccessor.buildContext.router.replaceAll(routes);
  }

  @override
  void dispose() {
    _disposed = true;
    _runContext?.cancel();
    super.dispose();
  }

}
