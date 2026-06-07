import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:h3xboard/app_router.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/views/connection_banner.dart';

class BoardApp extends StatefulWidget {

  const BoardApp({super.key});

  @override
  State<BoardApp> createState() => _BoardAppState();

}

class _BoardAppState extends State<BoardApp> {

  final _appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    return FluentApp.router(
      routerConfig: _appRouter.config(
        reevaluateListenable: GetIt.I<SessionController>(),
      ),
      builder: (context, child) => ConnectionBanner(child: child ?? const SizedBox.shrink()),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FluentLocalizations.delegate,
      ],
      supportedLocales: [Locale('en'), Locale('nl')],
      theme: FluentThemeData(
        accentColor: Color(0xFF00FF80).toAccentColor(),
        typography: Typography.fromBrightness(
          brightness: Brightness.light,
        ).apply(fontFamily: GoogleFonts.ubuntu().fontFamily),
        visualDensity: VisualDensity.standard,
      ),
    );
  }

}
