import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/pending_navigation_service.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/widgets/server_chip.dart';
import 'package:h3xboard/widgets/themable_loading_dialog.dart';
import 'package:polly_dart/polly_dart.dart';

@RoutePage()
class InitializationScreen extends StatefulWidget {

  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();

}

class _InitializationScreenState extends State<InitializationScreen> {

  // Exponential backoff with max 15 seconds wait time and infinite tries.
  static final ResiliencePipeline pipeline = ResiliencePipelineBuilder()
      .addRetry(RetryStrategyOptions.infinite(maxDelay: Duration(seconds: 15)))
      .build();

  final ServerController _server = GetIt.I<ServerController>();

  /// The context of the bootstrap run currently in flight. Cancelling it breaks
  /// the (otherwise infinite) retry loop; a run whose context is no longer the
  /// current one is stale and must not touch state or navigate.
  ResilienceContext? _runContext;

  String? nowInitializingText;
  int retries = 0;

  @override
  void initState() {
    super.initState();
    unawaited(initializeApp());
  }

  /// Bootstraps the app, then navigates to Start (authenticated) or Login (not).
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

  Future<void> _bootstrap(ResilienceContext runContext) async {
    bool isStale() => !mounted || _runContext != runContext;

    await pipeline.execute(
      (ctx) async {
        updateProgress(runContext, nowInitializingText: 'Loading fonts ...', retries: ctx.attemptNumber);
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
        updateProgress(runContext, nowInitializingText: 'Checking session ...', retries: ctx.attemptNumber);
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
      if (mounted) await context.router.replaceAll([LoginRoute()]);
      return;
    }

    // Establish the socket before flipping the status, so Start lands ready.
    await pipeline.execute(
      (ctx) async {
        updateProgress(runContext, nowInitializingText: 'Connecting to server ...', retries: ctx.attemptNumber);
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
    if (mounted) {
      final pending = GetIt.I<PendingNavigationService>().consumePendingRoute();
      await context.router.replaceAll([pending ?? const BoardsRoute()]);
    }
  }

  /// Re-points the app at [url] and restarts the bootstrap from scratch, so the
  /// session check runs again against the new server (which may well have a
  /// valid cookie of its own).
  Future<void> changeServer(String url) async {
    _runContext?.cancel();
    await _server.setServerUrl(url);
    if (!mounted) return;
    setState(() {
      nowInitializingText = null;
      retries = 0;
    });
    await initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FluentTheme.of(context).scaffoldBackgroundColor,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ThemableLoadingDialog(
              message: nowInitializingText ?? 'Initializing ...',
              subtitle: retries > 0 ? 'Tried $retries time(s)' : null,
            ),
            // The escape hatch when the configured server is unreachable: the
            // steps above would otherwise retry forever with no way to see, let
            // alone fix, which host the app is stuck on.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 368),
              child: ServerChip(
                serverUrl: _server.serverUrl,
                onEdit: () => showServerUrlDialog(
                  context,
                  currentUrl: _server.serverUrl,
                  onSave: changeServer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Applies progress from [runContext]'s run, ignoring updates from a run that
  /// has since been superseded by a server change.
  void updateProgress(
    ResilienceContext runContext, {
    required String nowInitializingText,
    required int retries,
  }) {
    if (!mounted || _runContext != runContext) return;
    setState(() {
      this.nowInitializingText = nowInitializingText;
      this.retries = retries;
    });
  }

  @override
  void dispose() {
    _runContext?.cancel();
    super.dispose();
  }

}
