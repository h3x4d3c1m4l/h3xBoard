import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:h3xboard/theme/shape_metrics.dart';

FluentThemeData buildAppTheme() {
  final FluentThemeData theme = FluentThemeData(
    accentColor: const Color(0xFF00FF80).toAccentColor(),
    typography: Typography.fromBrightness(
      brightness: Brightness.light,
    ).apply(fontFamily: GoogleFonts.lexend().fontFamily),
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: const Color(0xFFEAE9E6),
  );

  return theme.copyWith(
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
    ),
  );
}
