import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:h3xboard/theme/app_theme.dart';
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

  // The app's own tokens. Fluent's per-widget-type slots below are wired to the
  // matching roles, so there is exactly one place a button style is written down.
  final appTheme = AppTheme.standard(theme);
  final buttons = appTheme.buttons;

  return theme.copyWith(
    extensions: [appTheme],
    infoBarTheme: InfoBarThemeData(
      decoration: (severity) {
        final res = theme.resources;
        final Color color = switch (severity) {
          InfoBarSeverity.info => res.systemFillColorAttentionBackground,
          InfoBarSeverity.warning => res.systemFillColorCautionBackground,
          InfoBarSeverity.success => res.systemFillColorSuccessBackground,
          InfoBarSeverity.error => res.systemFillColorCriticalBackground,
        };
        return ShapeDecoration(
          color: color,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(kControlCornerRadius),
            side: BorderSide(color: res.cardStrokeColorDefault),
          ),
        );
      },
    ),
    tooltipTheme: TooltipThemeData(
      decoration: ShapeDecoration(
        color: theme.menuColor,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(kTooltipCornerRadius),
          side: BorderSide(color: theme.resources.surfaceStrokeColorFlyout),
        ),
      ),
    ),
    // Spelled out per style rather than via `ButtonThemeData.all`, which would
    // hand `kControlPadding` to icon buttons too — 24px of horizontal padding
    // around a bare 20px glyph, which reads as oversized next to everything else.
    buttonTheme: ButtonThemeData(
      // The plain Button and the OutlinedButton are the app's secondary actions
      // (Cancel, "Watch a board", "Upload photo", "Reset to default"), so they
      // carry the neutral outline. The accent-filled, hyperlink and icon buttons
      // define themselves and stay borderless.
      defaultButtonStyle: buttons.neutral,
      filledButtonStyle: buttons.control,
      hyperlinkButtonStyle: buttons.control,
      outlinedButtonStyle: buttons.neutral,
      iconButtonStyle: buttons.icon,
    ),
    // A ToggleButton is a Button underneath, and fluent styles only its *checked*
    // state — with rounded corners, the one place a selected toggle would break
    // the squircle language — leaving the unchecked one to fall through to
    // `defaultButtonStyle` above. The toolbar's tool buttons and stroke presets
    // are toggles carrying their own selected/unselected language, so spell both
    // states out here.
    toggleButtonTheme: ToggleButtonThemeData(
      checkedButtonStyle: buttons.toggleChecked,
      uncheckedButtonStyle: buttons.control,
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
