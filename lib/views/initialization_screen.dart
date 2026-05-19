import 'package:auto_route/auto_route.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:h3xboard/app_router.gr.dart';
import 'package:polly_dart/polly_dart.dart';

@RoutePage()
class InitializationScreen extends StatefulWidget {

  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();

}

class _InitializationScreenState extends State<InitializationScreen> {

  // Create a resilience pipeline with exponential backoff with max 15 seconds wait time and infinite tries.
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

  Future<void> initializeApp() async {
    // Load fonts.
    await pipeline.execute((context) async {
      updateProgress(
        nowInitializingText: 'Loading fonts',
        retries: context.attemptNumber,
      );

      await GoogleFonts.pendingFonts([
        GoogleFonts.ubuntu(),
      ]);
    });

    if (mounted) {
      await context.replaceRoute(DashboardRoute());
    }
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
            if (nowInitializingText != null) Text(nowInitializingText!),
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
