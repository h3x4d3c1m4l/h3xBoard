import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/routing/app_router.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/theme/theme.dart';
import 'package:h3xboard/views/connection_banner.dart';
import 'package:h3xboard/views/debug/debug_overlay.dart';

class BoardApp extends StatefulWidget {

  const BoardApp({super.key});

  @override
  State<BoardApp> createState() => _BoardAppState();

}

class _BoardAppState extends State<BoardApp> {

  final _appRouter = GetIt.I<AppRouter>();

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = buildAppTheme();
    // Observe the language setting so changing it in the Settings dialog
    // re-localizes the whole app immediately. null locale = follow the device.
    return Observer(
      builder: (context) => FluentApp.router(
        locale: GetIt.I<AppSettingsController>().language.locale,
        routerConfig: _appRouter.config(
          reevaluateListenable: GetIt.I<SessionController>(),
        ),
        builder: (context, child) {
          Widget content = child ?? const SizedBox.shrink();
          Widget connectionBanner = ConnectionBanner(child: content);
          return kDebugMode ? DebugOverlay(child: connectionBanner) : connectionBanner;
        },
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FluentLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('nl')],
        theme: theme,
      ),
    );
  }

}
