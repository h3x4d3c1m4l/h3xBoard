import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_metrics.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

/// The Code Playground's palette and type.
///
/// Board widgets are canvas content rather than app chrome, so — like the clock,
/// the piano and the to-do list — this one draws itself in literal colours over
/// the dark glass card instead of reading fluent's light-theme resources. The
/// accent comes from the theme, because it means the same thing app-wide.
class CodePlaygroundStyle {

  /// Overrides the monospace family in tests.
  ///
  /// Going through google_fonts in a widget test starts an async font load that
  /// outlives the test and fails it *after* it has passed — the same trick, and
  /// the same reason, as `TextBoxWidget.debugFontFamily`.
  @visibleForTesting
  static String? debugFontFamily;

  const CodePlaygroundStyle._();

  static const Color card = Color(0xE6111827);
  static const Color onCard = Color(0xFFFFFFFF);

  /// A shade darker than the card, so the editor and the panels read as insets
  /// rather than as more card.
  static const Color well = Color(0xFF0B111C);

  static Color get cardBorder => onCard.withValues(alpha: 0.24);
  static Color get wellBorder => onCard.withValues(alpha: 0.14);
  static Color get secondary => onCard.withValues(alpha: 0.70);
  static Color get muted => onCard.withValues(alpha: 0.45);
  static Color get faint => onCard.withValues(alpha: 0.28);

  /// Errors and tracebacks. Red rather than the theme's accent because a failed
  /// run is the one thing that must be unmistakable across a classroom.
  static const Color error = Color(0xFFF87171);

  /// A finished, successful run.
  static const Color success = Color(0xFF4ADE80);

  static Color accent(BuildContext context) => FluentTheme.of(context).accentColor;

  /// Syntax colours for the code editor.
  ///
  /// Atom One Dark. Only the per-token entries matter: re_editor looks the map
  /// up by highlight class name and never reads `root`, so the theme's own
  /// background and base colour are dead here — [well] and [onCard] are handed
  /// to the editor separately.
  static Map<String, TextStyle> get syntaxTheme => atomOneDarkTheme;

  /// The monospace family name, for APIs that take a family rather than a style.
  ///
  /// Resolving it through google_fonts keeps it identical to what [mono] uses,
  /// so the editor and the output panel cannot drift apart.
  static String? monoFontFamily() =>
      debugFontFamily ?? GoogleFonts.ibmPlexMono().fontFamily;

  /// IBM Plex Mono — for code, input and output, where columns must line up.
  ///
  /// [color] is nullable on purpose and has no fallback, so callers that want the
  /// syntax theme to decide can leave it alone.
  static TextStyle mono({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double height = 1.45,
  }) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
    final family = debugFontFamily;
    return family == null ? GoogleFonts.ibmPlexMono(textStyle: base) : base.copyWith(fontFamily: family);
  }

  /// The app's UI face, for labels and buttons.
  static TextStyle label({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? secondary,
        letterSpacing: letterSpacing,
        height: 1.2,
      );

  /// The small upper-case caption over a pane.
  static TextStyle caption() =>
      label(fontSize: kLabelFontSize, fontWeight: FontWeight.w600, color: muted, letterSpacing: 1.1);

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: cardBorder),
      );

  static BoxDecoration wellDecoration({Color? borderColor}) => BoxDecoration(
        color: well,
        borderRadius: BorderRadius.circular(kPanelRadius),
        border: Border.all(color: borderColor ?? wellBorder),
      );

  /// fluent [Button]s restyled for the dark card.
  ///
  /// The app-wide button theme is drawn for light chrome — `buttons.neutral` is a
  /// grey-outlined pill with dark text, which here would be a dark button on a
  /// dark background. Merging a local theme keeps fluent's button doing the work
  /// and changes only its colours.
  static ButtonThemeData buttonTheme(BuildContext context) {
    const padding = WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 12));
    final shape = WidgetStatePropertyAll<ShapeBorder?>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: wellBorder),
      ),
    );

    return ButtonThemeData(
      defaultButtonStyle: ButtonStyle(
        shape: shape,
        padding: padding,
        backgroundColor: WidgetStatePropertyAll(onCard.withValues(alpha: 0.08)),
        foregroundColor: WidgetStatePropertyAll(onCard),
      ),
      filledButtonStyle: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
        padding: padding,
        backgroundColor: WidgetStatePropertyAll(accent(context)),
        foregroundColor: const WidgetStatePropertyAll(Color(0xFF0B1220)),
      ),
    );
  }

}
