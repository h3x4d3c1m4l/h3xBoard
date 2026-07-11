import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:h3xboard/external_display/external_display_view.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/theme/theme.dart';

/// The root widget of the external-display isolate. Kept minimal (no router, no
/// GetIt, no API client): it shares nothing with the main app except the theme
/// and localizations, plus the board data pushed over the plugin's bus.
class ExternalDisplayApp extends StatelessWidget {

  const ExternalDisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FluentLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('nl')],
      theme: buildAppTheme(),
      home: const ExternalDisplayView(),
    );
  }

}
