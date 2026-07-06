import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:h3xboard/app_router.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
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
    final theme = FluentThemeData(
      accentColor: Color(0xFF00FF80).toAccentColor(),
      scaffoldBackgroundColor: const Color(0xFFEAE9E6),
      typography: Typography.fromBrightness(
        brightness: Brightness.light,
      ).apply(fontFamily: GoogleFonts.lexend().fontFamily),
      visualDensity: VisualDensity.standard,
    );
    // Observe the language setting so changing it in the Settings dialog
    // re-localizes the whole app immediately. null locale = follow the device.
    return Observer(
      builder: (context) => FluentApp.router(
      locale: GetIt.I<AppSettingsController>().language.locale,
      routerConfig: _appRouter.config(
        reevaluateListenable: GetIt.I<SessionController>(),
      ),
      builder: (context, child) {
        Widget connectionBanner = ConnectionBanner(child: child ?? const SizedBox.shrink());
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
      theme: theme.copyWith(
        // Apply the continuous-rectangle button shape app-wide (every fluent
        // button, not just dialog actions). Radius is concentric to the dialog
        // (see shape_metrics.dart).
        buttonTheme: ButtonThemeData.all(
          ButtonStyle(
            padding: WidgetStatePropertyAll(kControlPadding),
            shape: WidgetStatePropertyAll(
              ContinuousRectangleBorder(borderRadius: BorderRadius.circular(kControlCornerRadius)),
            ),
          ),
        ),
        dialogTheme: ContentDialogThemeData(
          decoration: ShapeDecoration(
            // Subtle accent tint over the dialog surface. Bump the alpha for a
            // stronger wash; the white background pattern reads against it.
            color: Color.alphaBlend(
              theme.accentColor.withValues(alpha: 0.12),
              theme.menuColor,
            ),
            shape: ContinuousRectangleBorder(
              borderRadius: .circular(kDialogCornerRadius),
              side: BorderSide(color: theme.accentColor, width: 2),
            ),
            shadows: kElevationToShadow[6],
          ),
          // Note: actionsDecoration is intentionally omitted. ThemableContentDialog
          // ignores it and fills the actions area with micaBackgroundColor, clipped
          // to the decoration shape above.
        ),
      ),
    ),
    );
  }

}
