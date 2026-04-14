import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:h3xboard/app_router.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';

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
      routerConfig: _appRouter.config(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FluentLocalizations.delegate,
      ],
      theme: FluentThemeData(
        typography: Typography.fromBrightness(
          brightness: Brightness.light,
        ).apply(fontFamily: GoogleFonts.ubuntu().fontFamily),
      ),
    );
  }

}
