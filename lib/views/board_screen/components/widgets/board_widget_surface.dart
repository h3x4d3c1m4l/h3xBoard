import 'dart:ui' show ImageFilter;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/theme/shape_metrics.dart';

/// The card a board widget draws itself on.
///
/// Six widgets used to spell out the same `BoxDecoration` — `0xE6111827`, a
/// 16px radius and a white hairline — and any change had to be made six times.
/// This is that card, said once, and it is what makes them look like one family
/// rather than six things that happen to agree.
///
/// Acrylic rather than a flat fill: a whiteboard has drawings, a background
/// image or a chalkboard behind it, and letting that show through blurred is
/// what makes a widget read as sitting *on* the board rather than pasted over
/// it. The tokens live on [AppBoardWidgetSurface] so the tint and the blur are
/// tuned in one place, not per widget.
class BoardWidgetSurface extends StatelessWidget {

  final Widget child;

  /// Inner padding, inside the border.
  final EdgeInsetsGeometry? padding;

  /// Overrides the corner radius for a widget whose proportions need it — the
  /// default suits a card a few hundred canvas units across.
  final double radius;

  /// How the child is placed when the surface is larger than it. Null lets the
  /// child size the surface, which is what a `Column` of rows wants.
  final AlignmentGeometry? alignment;

  /// Overrides the hairline, for a widget that says something with its edge —
  /// the timer flashes its border red when it finishes.
  final Color? borderColor;

  const BoardWidgetSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = kBoardWidgetCornerRadius,
    this.alignment,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _build(context, constraints.biggest),
    );
  }

  Widget _build(BuildContext context, Size size) {
    final surface = context.appTheme.surfaces.boardWidget;
    final content = padding == null ? child : Padding(padding: padding!, child: child);
    final tokens = borderColor == null ? surface : surface.copyWith(borderColor: borderColor);

    // Never more than half the shortest side. Past that a continuous rectangle
    // has no straight edge left to run and collapses into a lozenge, and the
    // widgets differ enough in proportion that one number cannot suit all of
    // them: the clock is 300x100, the playground 940x764. Clamping here means
    // the token can be set for how the big cards should look, and the small ones
    // quietly stop at their own pill instead of going misshapen.
    final limit = size.shortestSide.isFinite ? size.shortestSide / 2 : radius;
    final shape = tokens.shapeOf(radius: radius.clamp(0.0, limit));

    // Didn't like the way the Acrylic widget of fluent_ui looked,
    // as such the effect is composed in a custom way here.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(shape: shape),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: surface.blurAmount, sigmaY: surface.blurAmount),
          child: ColoredBox(
            color: surface.tint.withValues(alpha: surface.tintAlpha),
            child: alignment == null ? content : Align(alignment: alignment!, child: content),
          ),
        ),
      ),
    );
  }

}
