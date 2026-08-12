import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:theme_tailor_annotation/theme_tailor_annotation.dart';

part 'app_theme.tailor.dart';

/// The gray outline on a neutral (secondary) button. Fluent's own control stroke
/// is barely a shade off white, which leaves those buttons melting into the light
/// surface behind them — most of all a dialog's gray actions bar.
const Color _kNeutralButtonBorderColor = Color(0xFFC4C9D1);

/// Caches the fallback tokens per [FluentThemeData], so a subtree themed without
/// [AppTheme] doesn't rebuild them on every widget build.
final Expando<AppTheme> _fallbackCache = Expando<AppTheme>('AppTheme fallback');

extension AppThemeContext on BuildContext {

  /// The app's design tokens for this subtree.
  ///
  /// Falls back to [AppTheme.standard] when the ambient theme carries no
  /// [AppTheme] — a widget test that builds its own [FluentThemeData], say. The
  /// tokens are derived from whatever theme *is* there, so the fallback still
  /// tracks its accent color rather than snapping to some app-wide default.
  AppTheme get appTheme {
    final theme = FluentTheme.of(this);
    return theme.extension<AppTheme>() ?? (_fallbackCache[theme] ??= AppTheme.standard(theme));
  }

}

/// The app's own design tokens, hung off fluent's theme as a [ThemeExtension].
///
/// Fluent's [FluentThemeData] can only describe a control by its *widget type*
/// — one `defaultButtonStyle` for every [Button] in the app. Our buttons carry
/// far more meaning than that: a Cancel button, a toolbar tool, a sub-board tab
/// and the Exit button are all plain [Button]s wearing completely different
/// clothes. This extension names those roles, so a widget asks for the style it
/// *means* (`context.appTheme.buttons.exit`) instead of spelling out padding,
/// shape and colors inline.
///
/// Read it anywhere with `context.appTheme` (generated below), or off a theme you
/// already have via `theme.extension<AppTheme>()`.
@TailorMixin(themeGetter: ThemeGetter.none)
class AppTheme extends ThemeExtension<AppTheme> with _$AppThemeTailorMixin {

  const AppTheme({
    required this.buttons,
    required this.surfaces,
    required this.dialogs,
    required this.colors,
  });

  /// Builds the app's tokens from the fluent theme they sit on, so anything
  /// derived from the accent color or fluent's resources stays in sync.
  factory AppTheme.standard(FluentThemeData theme) {
    return AppTheme(
      buttons: AppButtonStyles.standard(theme),
      surfaces: AppSurfaceStyles.standard(theme),
      dialogs: const AppDialogStyles(),
      colors: const AppSemanticColors(),
    );
  }

  @override
  final AppButtonStyles buttons;

  @override
  final AppSurfaceStyles surfaces;

  @override
  final AppDialogStyles dialogs;

  @override
  final AppSemanticColors colors;

}

/// The surfaces the app floats over the board.
@TailorMixinComponent()
class AppSurfaceStyles extends ThemeExtension<AppSurfaceStyles> with _$AppSurfaceStylesTailorMixin {

  const AppSurfaceStyles({
    required this.toolbar,
    this.boardWidget = const AppBoardWidgetSurface(),
    this.toolbarPadding = kToolbarPadding,
  });

  factory AppSurfaceStyles.standard(FluentThemeData theme) {
    return AppSurfaceStyles(
      toolbar: ShapeDecoration(
        color: theme.micaBackgroundColor,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(kToolbarCornerRadius),
          side: BorderSide(color: theme.resources.cardStrokeColorDefault),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }

  /// A floating toolbar: the drawing tool bar and the text widget's format bar.
  /// Lifted off the board with a soft shadow, so it reads as hovering over the
  /// drawing rather than sitting in it.
  @override
  final ShapeDecoration toolbar;

  /// The card a board widget draws itself on. See [AppBoardWidgetSurface].
  @override
  final AppBoardWidgetSurface boardWidget;

  /// [toolbar]'s inner padding, around the buttons it holds.
  @override
  final EdgeInsetsGeometry toolbarPadding;

}

/// A board widget's own surface — the dark glass card a clock, a timer or the
/// code playground sits on.
///
/// Acrylic rather than a flat fill: these float over a whiteboard that has
/// drawings, a background image or a chalkboard behind them, and letting that
/// show through blurred is what makes them read as *on* the board rather than
/// pasted over it.
///
/// Tokens rather than a finished decoration because fluent's [Acrylic] takes
/// them apart — tint, alpha and blur are separate arguments, and only [shape] is
/// a [ShapeBorder]. Widgets do not read these directly; they use
/// `BoardWidgetSurface`, which is the one place they are assembled.
@TailorMixinComponent()
class AppBoardWidgetSurface extends ThemeExtension<AppBoardWidgetSurface>
    with _$AppBoardWidgetSurfaceTailorMixin {

  const AppBoardWidgetSurface({
    this.tint = const Color(0xFF111827),
    this.tintAlpha = 0.68,
    this.blurAmount = 12,
    this.borderColor = const Color(0x3DFFFFFF),
    this.onSurface = const Color(0xFFFFFFFF),
  });

  /// The near-black these cards have always been. Kept as an opaque colour with
  /// [tintAlpha] beside it so the two can be tuned independently.
  @override
  final Color tint;

  /// How much of the board shows through. Low enough to read as glass over a
  /// drawing, high enough that white text stays legible over whatever is behind
  /// it — that lower bound is what stops this going further.
  ///
  /// Only trustworthy because the blur is composited beneath the tint rather
  /// than through it; see `BoardWidgetSurface`. Blurred *with* it, a low alpha
  /// here thinned the card's edges out to nothing.
  @override
  final double tintAlpha;

  /// Deliberately modest. Every one of these is a separate `BackdropFilter`, and
  /// a busy board renders the same widgets again on the external display and for
  /// every web viewer.
  @override
  final double blurAmount;

  /// The hairline that keeps the card's edge legible over a dark drawing, where
  /// the tint alone would disappear.
  @override
  final Color borderColor;

  /// What is legible on top of [tint] — the text and glyphs every one of these
  /// widgets draws.
  @override
  final Color onSurface;

}

/// The squircle a board widget's surface is cut to.
///
/// A method rather than a getter on [AppBoardWidgetSurface]: theme_tailor treats
/// every public getter on a token class as a field, and would put this derived
/// value into the generated `copyWith` and `lerp` as though it could vary
/// independently of the [AppBoardWidgetSurface.borderColor] it is built from.
extension AppBoardWidgetSurfaceShape on AppBoardWidgetSurface {

  ShapeBorder shapeOf({double radius = kBoardWidgetCornerRadius}) => ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor),
      );

}

/// One [ButtonStyle] per *role* a button plays in this app.
///
/// [control] is the shared base — every other style starts from it, so the
/// squircle corner radius and control padding are stated once.
@TailorMixinComponent()
class AppButtonStyles extends ThemeExtension<AppButtonStyles> with _$AppButtonStylesTailorMixin {

  const AppButtonStyles({
    required this.borderColor,
    required this.control,
    required this.neutral,
    required this.comboBox,
    required this.icon,
    required this.toggleChecked,
    required this.toolbarItem,
    required this.toolbarItemChecked,
    required this.tab,
    required this.exit,
  });

  factory AppButtonStyles.standard(FluentThemeData theme) {
    final control = ButtonStyle(
      padding: WidgetStatePropertyAll(kControlPadding),
      shape: WidgetStatePropertyAll(
        ContinuousRectangleBorder(borderRadius: BorderRadius.circular(kControlCornerRadius)),
      ),
    );
    final checkedColors = ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) => FilledButton.foregroundColor(theme, states)),
      backgroundColor: WidgetStateProperty.resolveWith((states) => FilledButton.backgroundColor(theme, states)),
    );

    return AppButtonStyles(
      borderColor: _kNeutralButtonBorderColor,
      control: control,
      neutral: control.copyWith(shape: _outlinedShape(kControlCornerRadius)),
      comboBox: control.copyWith(shape: _outlinedShape(kShortControlCornerRadius)),
      icon: control.copyWith(padding: const WidgetStatePropertyAll(kIconControlPadding)),
      toggleChecked: checkedColors.copyWith(padding: control.padding, shape: control.shape),
      // The toolbars leave `shape` out on purpose: a tool button is concentric
      // with whichever bar holds it, so [ToggleButtonToolbar] fills in the radius
      // it was given. Everything else about the role lives here.
      toolbarItem: const ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      toolbarItemChecked: checkedColors,
      tab: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsetsDirectional.symmetric(horizontal: kTabHorizontalPadding, vertical: kTabVerticalPadding),
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          ContinuousRectangleBorder(borderRadius: BorderRadius.circular(kSubBoardTabButtonRadius)),
        ),
      ),
      exit: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsetsDirectional.symmetric(horizontal: kTabHorizontalPadding, vertical: kTabVerticalPadding),
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(kExitButtonRadius))),
      ),
    );
  }

  /// The app's squircle at [radius], outlined in [borderColor] — faded while the
  /// control is disabled, so a grayed-out button doesn't read as the most defined
  /// thing in the row.
  static WidgetStateProperty<ShapeBorder?> _outlinedShape(double radius) {
    return WidgetStateProperty.resolveWith((states) {
      return ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: states.contains(WidgetState.disabled)
              ? _kNeutralButtonBorderColor.withValues(alpha: 0.35)
              : _kNeutralButtonBorderColor,
        ),
      );
    });
  }

  /// The outline on [neutral], also used where a widget draws that edge itself.
  @override
  final Color borderColor;

  /// The shared base: control padding and the app's squircle corners, no border.
  /// Fluent's accent-filled, hyperlink and (via [icon]) icon buttons all use it.
  @override
  final ButtonStyle control;

  /// The app's secondary action — Cancel, "Watch a board", "Upload photo",
  /// "Reset to default". [control] plus the [borderColor] outline, which fades
  /// when the button is disabled so a grayed-out action doesn't read as the most
  /// defined thing in the row.
  @override
  final ButtonStyle neutral;

  /// A dropdown's closed state — [neutral]'s outline on the smaller
  /// [kShortControlCornerRadius], because fluent pins a `ComboBox` to a fixed
  /// 32px height that the full control radius would swallow.
  ///
  /// Applied by `ContinuousComboBox`; fluent builds the closed state out of a
  /// plain [Button], so there is no combo-box theme slot to hang it on.
  @override
  final ButtonStyle comboBox;

  /// Icon-only buttons: [control] with square padding, since there is no label to
  /// give room to.
  @override
  final ButtonStyle icon;

  /// A checked [ToggleButton]: fluent's accent fill on the app's squircle.
  /// Fluent's own checked style hardcodes a rounded rectangle, which is the one
  /// place a selected toggle would break the squircle language.
  @override
  final ButtonStyle toggleChecked;

  /// A tool button in the drawing toolbars, unselected: transparent, letting the
  /// bar's own surface show through.
  @override
  final ButtonStyle toolbarItem;

  /// The same tool button while selected: fluent's accent fill.
  @override
  final ButtonStyle toolbarItemChecked;

  /// A sub-board tab's label button — transparent, hugging the tab indicator
  /// that draws around it.
  @override
  final ButtonStyle tab;

  /// The board screen's "Exit" button: transparent, quieter corners than the
  /// app's squircle controls because it sits in the top bar rather than on a
  /// surface of its own.
  @override
  final ButtonStyle exit;

}

/// Surface tokens for the app's two dialog shells ([ThemableContentDialog] and
/// [ThemablePanelDialog]).
@TailorMixinComponent()
class AppDialogStyles extends ThemeExtension<AppDialogStyles> with _$AppDialogStylesTailorMixin {

  const AppDialogStyles({
    this.panelSurfaceColor = Colors.white,
    this.panelBorderColor = const Color(0xFF6B7280),
    this.panelBorderWidth = 1.5,
    this.patternColor = const Color(0xCCFFFFFF),
  });

  /// The calm surface behind a large panel dialog (Settings, Add Widget).
  @override
  final Color panelSurfaceColor;

  /// The slate-gray frame around that surface.
  @override
  final Color panelBorderColor;

  @override
  final double panelBorderWidth;

  /// The pencil/eraser watermark drawn behind a confirmation dialog's content:
  /// white, softened just enough to stay a watermark.
  @override
  final Color patternColor;

}

/// Restores the plain, borderless [AppButtonStyles.control] for a subtree.
///
/// Fluent assembles several *controls* out of a plain [Button] — the
/// [ColorPicker]'s internals, a [ComboBox]'s closed state — so the app-wide
/// `defaultButtonStyle` (which is [AppButtonStyles.neutral]) reaches them too,
/// and a picker's internal buttons wearing the neutral outline read as a row of
/// separate controls. Wrap those in
/// `ButtonTheme.merge(data: plainControlButtonTheme(context), …)` to opt back out.
///
/// Dropdowns take the opposite route — they *want* a shape, just a smaller one —
/// so they go through `ContinuousComboBox` and [AppButtonStyles.comboBox].
ButtonThemeData plainControlButtonTheme(BuildContext context) {
  return ButtonThemeData(defaultButtonStyle: context.appTheme.buttons.control);
}

/// Colors that carry a meaning rather than a place — the ones a widget would
/// otherwise hardcode.
@TailorMixinComponent()
class AppSemanticColors extends ThemeExtension<AppSemanticColors> with _$AppSemanticColorsTailorMixin {

  const AppSemanticColors({
    this.destructive = const Color(0xFFEF4444),
    this.selection = const Color(0xFF3B82F6),
  });

  /// Delete/remove actions — the red on a "Delete" menu item's glyph, and what a
  /// destructive header-bar button turns on hover.
  @override
  final Color destructive;

  /// The selected board widget's outline, its resize/rotate handles and its
  /// header bar's active glyphs. Deliberately not the app accent: it marks
  /// *what is selected*, and has to stay legible over drawings in the accent
  /// color.
  @override
  final Color selection;

}
