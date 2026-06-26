import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ── Tuning knobs for the dialog's animated background pattern ──────────────
/// Seconds for one full seamless loop — the grid advances by
/// [_kPatternDriftX]/[_kPatternDriftY] cells over this time. Lower = faster.
const double _kPatternLoopSeconds = 16;

/// Opacity of the white pattern icons over the accent-tinted dialog surface.
const double _kPatternIconOpacity = 0.8;

/// Size (px) of each tiled icon glyph. Smaller = daintier icons.
const double _kPatternIconSize = 18;

/// Grid cell size (px) — the spacing between icons. Smaller = denser, more icons.
const double _kPatternCellSize = 40;

/// Drift direction in grid cells per loop, per axis. Use any ints — the loop
/// stays seamless for any combination. `(1, 0)` = rightwards, `(1, 1)` =
/// down-right, `(1, -1)` = up-right, larger magnitudes = faster, `(0, 0)` =
/// static.
const int _kPatternDriftX = 1;

const int _kPatternDriftY = 0;

/// Tilt (degrees) of the whole icon lattice. `0` = axis-aligned grid; e.g. `20`
/// rotates the entire pattern (the drift direction rotates with it).
const double _kPatternTiltDegrees = -20;

/// The semantic tone of a [ThemableContentDialog], driving its tint and border
/// color. [normal] keeps the ambient [ContentDialogTheme] (accent) styling;
/// [warning] and [error] recolor the surface with Fluent UI's status colors.
enum ThemableDialogSeverity {

  normal,
  warning,
  error;

  /// The Fluent status color that tints the surface and paints the border, or
  /// `null` for [normal] (which defers to the ambient accent-based theme).
  Color? get primaryColor => switch (this) {
    ThemableDialogSeverity.normal => null,
    // Fluent's warningPrimaryColor is an orange-red; use the amber-gold from
    // Fluent's yellow swatch so warnings read distinctly yellow against errors.
    ThemableDialogSeverity.warning => Colors.yellow.darkest,
    ThemableDialogSeverity.error => Colors.errorPrimaryColor,
  };

  /// The status glyph shown beside the title, or `null` for [normal].
  IconData? get icon => switch (this) {
    ThemableDialogSeverity.normal => null,
    ThemableDialogSeverity.warning => LucideIcons.triangleAlert,
    ThemableDialogSeverity.error => LucideIcons.octagonAlert,
  };

}

/// A near drop-in clone of fluent_ui's [ContentDialog], reworked for better
/// themability.
///
/// It behaves exactly like [ContentDialog], reading its visuals from the
/// ambient [ContentDialogTheme] (so [FluentThemeData.dialogTheme] still
/// applies), with two intentional differences:
///
///  * [ContentDialogThemeData.actionsDecoration] is **ignored**. A custom
///    `actionsDecoration` paints its own shape/background on top of the dialog
///    and fights a custom outer [ContentDialogThemeData.decoration] (e.g. a
///    [ContinuousRectangleBorder]), causing corners to spill or shapes to
///    double up.
///  * Instead, the actions area is filled with a single flat background color
///    ([actionsBackgroundColor], defaulting to
///    [FluentThemeData.micaBackgroundColor]), and the whole dialog body is
///    clipped to the outer `decoration`'s shape so that fill always respects
///    the dialog's (possibly rounded) corners.
class ThemableContentDialog extends StatelessWidget {

  /// Creates a themable content dialog.
  const ThemableContentDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.style,
    this.severity = ThemableDialogSeverity.normal,
    this.actionsBackgroundColor,
    this.showBackgroundPattern = true,
    this.constraints = kDefaultContentDialogConstraints,
  });

  /// The title of the dialog. Usually, a [Text] widget.
  final Widget? title;

  /// The content of the dialog. Usually, a [Text] widget.
  final Widget? content;

  /// The actions of the dialog. Usually, a list of [Button]s.
  final List<Widget>? actions;

  /// The style used by this dialog. If non-null, it's merged with
  /// [FluentThemeData.dialogTheme].
  ///
  /// Note: [ContentDialogThemeData.actionsDecoration] is ignored — use
  /// [actionsBackgroundColor] to color the actions area instead.
  final ContentDialogThemeData? style;

  /// The semantic tone of the dialog. Defaults to [ThemableDialogSeverity.normal]
  /// (accent-themed); [ThemableDialogSeverity.warning] and
  /// [ThemableDialogSeverity.error] recolor the surface tint and border with
  /// Fluent UI's status colors.
  final ThemableDialogSeverity severity;

  /// The background color of the actions area.
  ///
  /// Defaults to [FluentThemeData.micaBackgroundColor] when null.
  final Color? actionsBackgroundColor;

  /// Whether to paint the slowly-animated pencil/eraser pattern behind the
  /// dialog content. Defaults to `true`.
  final bool showBackgroundPattern;

  /// The constraints of the dialog. It defaults to
  /// `BoxConstraints(maxWidth: 368, maxHeight: 756)`.
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {

    assert(debugCheckHasFluentTheme(context), 'A FluentTheme ancestor is required.');
    final theme = FluentTheme.of(context);
    final style = ContentDialogTheme.of(context).merge(this.style);
    final severityColor = severity.primaryColor;
    final decoration = _severityDecoration(style.decoration, severityColor, theme);
    // Wash the actions bar with the status color too, so it reads cohesively
    // with the recolored surface (a touch stronger than the body tint).
    final actionsColor =
        actionsBackgroundColor ??
        (severityColor == null
            ? theme.micaBackgroundColor
            : Color.alphaBlend(severityColor.withValues(alpha: 0.16), theme.micaBackgroundColor));
    // Recolor the primary (filled) action to the status color in severity modes;
    // the plain [Button] (e.g. Cancel) stays neutral. Layer the color override
    // onto the ambient filled style so the app-wide shape/padding survive.
    final actionThemeData = severityColor == null
        ? (style.actionThemeData ?? const ButtonThemeData())
        : (style.actionThemeData ?? const ButtonThemeData()).merge(
            ButtonThemeData(
              filledButtonStyle: (ButtonTheme.of(context).filledButtonStyle ?? const ButtonStyle())
                  .merge(_severityFilledButtonStyle(severityColor)),
            ),
          );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Padding(
            padding: style.padding ?? EdgeInsetsDirectional.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: style.titlePadding ?? EdgeInsetsDirectional.zero,
                    child: DefaultTextStyle.merge(
                      style: style.titleStyle,
                      child: severityColor == null || severity.icon == null
                          ? title!
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 10),
                                  child: Icon(severity.icon, color: severityColor),
                                ),
                                Expanded(child: title!),
                              ],
                            ),
                    ),
                  ),
                if (content != null)
                  Flexible(
                    child: Padding(
                      padding: style.bodyPadding ?? EdgeInsetsDirectional.zero,
                      child: DefaultTextStyle.merge(
                        style: style.bodyStyle,
                        child: content!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (actions != null)
          Container(
            // Intentionally ignores style.actionsDecoration; a flat fill keeps
            // the actions area in sync with the outer dialog shape.
            color: actionsColor,
            padding: style.actionsPadding,
            child: ButtonTheme.merge(
              data: actionThemeData,
              child: _buildActions(style),
            ),
          ),
      ],
    );

    // Apply the action button theme dialog-wide so content-area buttons share
    // the same shape as the action row (the actions row re-merges it above).
    final themedBody = ButtonTheme.merge(
      data: actionThemeData,
      child: body,
    );

    // Layer the animated pattern behind the content (above the menuColor fill).
    final layered = showBackgroundPattern
        ? Stack(
            children: [
              const Positioned.fill(child: _AnimatedIconPattern()),
              themedBody,
            ],
          )
        : themedBody;

    return Align(
      alignment: AlignmentDirectional.center,
      child: Container(
        constraints: constraints,
        decoration: decoration,
        // Clip the content (notably the flat actions fill and the pattern) to
        // the outer decoration's shape so nothing spills past rounded corners.
        child: decoration == null
            ? layered
            : ClipPath(
                clipper: _DecorationClipper(
                  decoration: decoration,
                  textDirection: Directionality.maybeOf(context),
                ),
                child: layered,
              ),
      ),
    );
  }

  /// Recolors [base] (the ambient dialog decoration) to [severityColor],
  /// preserving its shape, radius, border width and shadows. Returns [base]
  /// unchanged when [severityColor] is `null` (the [ThemableDialogSeverity.normal]
  /// case) or when the decoration isn't a recognized shape.
  Decoration? _severityDecoration(Decoration? base, Color? severityColor, FluentThemeData theme) {
    if (severityColor == null) return base;
    final tint = Color.alphaBlend(severityColor.withValues(alpha: 0.12), theme.menuColor);
    if (base is ShapeDecoration) {
      final shape = base.shape;
      return ShapeDecoration(
        color: tint,
        shape: shape is OutlinedBorder ? shape.copyWith(side: shape.side.copyWith(color: severityColor)) : shape,
        shadows: base.shadows,
        image: base.image,
        gradient: base.gradient,
      );
    }
    if (base is BoxDecoration) {
      return base.copyWith(
        color: tint,
        border: Border.all(color: severityColor, width: 2),
      );
    }
    return base;
  }

  /// A [FilledButton] style that paints the primary action in [color] instead
  /// of the theme accent, darkening on hover/press and choosing a black or
  /// white label for best contrast against the (possibly light) status color.
  ButtonStyle _severityFilledButtonStyle(Color color) {
    // Below this relative-luminance crossover white text wins for contrast
    // (WCAG-derived); above it black wins — so light amber warnings get dark
    // labels while dark-red errors keep white ones.
    final onColor = color.computeLuminance() < 0.179 ? Colors.white : Colors.black;
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return color.withValues(alpha: 0.4);
        if (states.contains(WidgetState.pressed)) return Color.alphaBlend(Colors.black.withValues(alpha: 0.16), color);
        if (states.contains(WidgetState.hovered)) return Color.alphaBlend(Colors.black.withValues(alpha: 0.08), color);
        return color;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? onColor.withValues(alpha: 0.5) : onColor,
      ),
    );
  }

  Widget _buildActions(ContentDialogThemeData style) {

    final actions = this.actions!;
    if (actions.length == 1) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: actions.first,
      );
    }

    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: .stretch,
        children: actions.map((e) {
          final index = actions.indexOf(e);
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                end: index != (actions.length - 1) ? style.actionsSpacing ?? 3 : 0,
              ),
              child: e,
            ),
          );
        }).toList(),
      ),
    );
  }

}

/// Clips its child to the shape produced by a [Decoration].
///
/// Works for any decoration that implements [Decoration.getClipPath], such as
/// [BoxDecoration] (with a `borderRadius`) and [ShapeDecoration] (with any
/// [ShapeBorder], e.g. [ContinuousRectangleBorder]).
class _DecorationClipper extends CustomClipper<Path> {

  const _DecorationClipper({required this.decoration, this.textDirection});

  final Decoration decoration;

  final TextDirection? textDirection;

  @override
  Path getClip(Size size) {
    return decoration.getClipPath(
      Offset.zero & size,
      textDirection ?? TextDirection.ltr,
    );
  }

  @override
  bool shouldReclip(_DecorationClipper oldClipper) {
    return oldClipper.decoration != decoration ||
        oldClipper.textDirection != textDirection;
  }

}

/// A subtle, slowly-drifting tiled background of pencil and eraser icons,
/// fitting h3xBoard's drawing-board theme. It scrolls diagonally and loops
/// seamlessly, reading as a faint watermark behind the dialog content.
class _AnimatedIconPattern extends StatefulWidget {

  const _AnimatedIconPattern();

  @override
  State<_AnimatedIconPattern> createState() => _AnimatedIconPatternState();

}

class _AnimatedIconPatternState extends State<_AnimatedIconPattern> with SingleTickerProviderStateMixin {

  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  Widget build(BuildContext context) {

    // Keep the loop duration responsive to a hot-reloaded _kPatternLoopSeconds
    // (the controller is created once, so set/refresh its duration here).
    final ms = (_kPatternLoopSeconds * 1000).round();
    if (_controller.duration?.inMilliseconds != ms) {
      _controller
        ..stop()
        ..duration = Duration(milliseconds: ms)
        ..repeat();
    }

    final color = Colors.white.withValues(alpha: _kPatternIconOpacity);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _IconPatternPainter(progress: _controller.value, color: color),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

}

/// Paints a checkerboard of pencil/eraser glyphs, drifting by [progress] (0..1)
/// in the `(_kPatternDriftX, _kPatternDriftY)` direction. The icons alternate on
/// `(row + col)` parity, so the field only maps onto itself after an even-sum
/// cell shift; [_loopCells] advances a whole such period per loop so the wrap is
/// seamless for *any* drift (odd-sum drifts advance two cells instead of one).
class _IconPatternPainter extends CustomPainter {

  _IconPatternPainter({required this.progress, required this.color});

  final double progress;

  final Color color;

  static const List<IconData> _icons = [LucideIcons.pencil, LucideIcons.eraser];

  /// Cells advanced per loop: 1 when the drift sum is even, else 2 (so the
  /// checkerboard parity lines up again at the wrap and nothing visibly swaps).
  static const int _loopCells = (_kPatternDriftX + _kPatternDriftY) % 2 == 0 ? 1 : 2;

  @override
  void paint(Canvas canvas, Size size) {
    final shiftX = progress * _kPatternCellSize * _kPatternDriftX * _loopCells;
    final shiftY = progress * _kPatternCellSize * _kPatternDriftY * _loopCells;

    // Lay out each glyph once, then paint it across every matching cell.
    final painters = _icons.map((icon) {
      return TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: _kPatternIconSize,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }).toList();

    // Tilt the whole lattice by rotating the canvas around its center.
    canvas.save();
    final center = Offset(size.width / 2, size.height / 2);
    canvas
      ..translate(center.dx, center.dy)
      ..rotate(_kPatternTiltDegrees * math.pi / 180)
      ..translate(-center.dx, -center.dy);

    // The rotated grid must still cover the whole canvas, so iterate over the
    // bounding box of the screen rect expressed in the (rotated) grid frame.
    // Half-extents of that box grow with the tilt; +1 cell of slack covers the
    // drift wrap and partial edge cells.
    final cos = math.cos(_kPatternTiltDegrees * math.pi / 180).abs();
    final sin = math.sin(_kPatternTiltDegrees * math.pi / 180).abs();
    final halfW = (size.width * cos + size.height * sin) / 2;
    final halfH = (size.width * sin + size.height * cos) / 2;

    final startCol = ((center.dx - halfW - shiftX) / _kPatternCellSize).floor() - 1;
    final endCol = ((center.dx + halfW - shiftX) / _kPatternCellSize).ceil() + 1;
    final startRow = ((center.dy - halfH - shiftY) / _kPatternCellSize).floor() - 1;
    final endRow = ((center.dy + halfH - shiftY) / _kPatternCellSize).ceil() + 1;

    for (var row = startRow; row <= endRow; row++) {
      for (var col = startCol; col <= endCol; col++) {
        final painter = painters[(row + col) & 1];
        final cellX = col * _kPatternCellSize + shiftX;
        final cellY = row * _kPatternCellSize + shiftY;
        painter.paint(
          canvas,
          Offset(
            cellX + (_kPatternCellSize - painter.width) / 2,
            cellY + (_kPatternCellSize - painter.height) / 2,
          ),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPatternPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }

}
