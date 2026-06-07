import 'package:auto_route/auto_route.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/session_controller.dart';
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

  String? nowInitializingText;
  int retries = 0;

  @override
  void initState() {
    super.initState();
    initializeApp();
  }

  /// Bootstraps the app, then hands navigation to the router guards: setting the
  /// session status notifies the `reevaluateListenable`, and [AuthGuard]
  /// redirects this one-time route to Start (authenticated) or Login (not).
  Future<void> initializeApp() async {
    await pipeline.execute((context) async {
      updateProgress(
        nowInitializingText: 'Loading fonts ...',
        retries: context.attemptNumber,
      );
      await GoogleFonts.pendingFonts([GoogleFonts.ubuntu()]);
    });

    final session = GetIt.I<SessionController>();
    final authService = GetIt.I<H3xBoardAuthService>();
    final wsClient = GetIt.I<H3xBoardApiClient>();

    // whoami() returns null on a 401 (definitively unauthenticated, not retried);
    // a network failure throws and is retried by the pipeline.
    final user = await pipeline.execute((context) async {
      updateProgress(
        nowInitializingText: 'Checking session ...',
        retries: context.attemptNumber,
      );
      return authService.whoami();
    });

    if (user == null) {
      session.markUnauthenticated();
      return;
    }

    // Establish the socket before flipping the status, so Start lands ready.
    await pipeline.execute((context) async {
      updateProgress(
        nowInitializingText: 'Connecting to server ...',
        retries: context.attemptNumber,
      );
      await wsClient.connect();
    });
    session.markAuthenticated(user.userId, user.email);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          ProgressRing(),
          if (nowInitializingText != null)
            Text(nowInitializingText!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (retries > 0) Text('Tried $retries time(s)'),
        ],
      ),
    );
  }

  void updateProgress({required String nowInitializingText, required int retries}) {
    setState(() {
      this.nowInitializingText = nowInitializingText;
      this.retries = retries;
    });
  }

}
