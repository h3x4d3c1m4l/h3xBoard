import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart' show PointerDeviceKind;

/// How far the fade at each end of a scrolled bar reaches.
const double kBarFadeExtent = 24;

/// How far [RelaxedCrossAxisClipper] lets a bar's controls paint past its sides.
///
/// Sized for the widest thing that does: the active colour swatch's glow, a
/// [BoxShadow] of `blurRadius: 16` on a circle that already fills its box.
const double kBarClipBleed = 24;

@visibleForTesting
const Key kBarFadeLeadingKey = ValueKey('barScrollArea.fade.leading');

@visibleForTesting
const Key kBarFadeTrailingKey = ValueKey('barScrollArea.fade.trailing');

/// Keeps a bar's scroll-axis bounds exactly and relaxes the cross axis by
/// [bleed].
///
/// The scroll axis MUST be clipped — that is what hides the controls scrolled
/// off the end. The cross axis must not be: a viewport clips to its own box, and
/// a bar's box is exactly as deep as its controls, so a flush clip cuts anything
/// they paint *outside* themselves. The colour swatch's glow is that: a
/// `blurRadius: 16` [BoxShadow] tinted with the swatch colour, which a flush clip
/// squares off into a band.
///
/// This is the cross-axis mirror of `RelaxedHorizontalClipper` in
/// `DialogScrollArea`, which solves the same problem for a vertical viewport
/// full of outlined controls.
class RelaxedCrossAxisClipper extends CustomClipper<Rect> {

  /// The axis the bar scrolls on — the one whose bounds are kept.
  final Axis scrollAxis;

  /// How far the clip reaches past each side of the cross axis.
  final double bleed;

  const RelaxedCrossAxisClipper({required this.scrollAxis, this.bleed = kBarClipBleed});

  @override
  Rect getClip(Size size) => scrollAxis == Axis.horizontal
      ? Rect.fromLTRB(0, -bleed, size.width, size.height + bleed)
      : Rect.fromLTRB(-bleed, 0, size.width + bleed, size.height);

  @override
  bool shouldReclip(RelaxedCrossAxisClipper oldClipper) =>
      oldClipper.scrollAxis != scrollAxis || oldClipper.bleed != bleed;

}

/// Lets a docked bar scroll once it outgrows the edge it is docked against — and
/// only then.
///
/// A bar lays itself out with `mainAxisSize: MainAxisSize.min` and is centred by
/// `BoardScaffold`, so it has to keep shrink-wrapping for as long as it fits. A
/// [SingleChildScrollView] sizes itself to `constraints.constrain(childSize)`,
/// which is exactly that behaviour: it takes the content's own size while the
/// content fits, and clamps to the room available once it does not. So the bar
/// stays snug and centred at normal window sizes and becomes scrollable only at
/// the point where it would otherwise overflow.
///
/// The caller MUST hand this a **bounded** main-axis constraint. A [Flex] gives
/// its non-flexible children unbounded main-axis constraints, and under those a
/// scroll view just takes its natural size and never scrolls — the overflow comes
/// back, silently. That is why `BalancedTrailing` puts the bar in a loose
/// [Flexible] rather than passing it straight through.
///
/// ## Nothing is clipped or layered while the bar fits
///
/// Both the clip and the fade are mounted only while something is actually
/// scrolled out of view. That is not only about cost. A bar's controls paint
/// outside their own boxes — see [RelaxedCrossAxisClipper] — and a bar that fits
/// has nothing to hide, so the correct number of clips is zero. The viewport
/// itself is handed [Clip.none] and never does its own clipping.
///
/// ## Why the fade is an overlay, and why one bar goes without
///
/// Fading the content's *alpha* would be background-independent, and that was
/// the first attempt here: a [ShaderMask] with [BlendMode.dstIn]. It cannot
/// work. [RenderShaderMask] sets `maskRect = offset & size`, so the mask covers
/// the bar's own box and the blend erases everything painted beyond it — the
/// swatch glow included. A mask cannot be relaxed the way a clip can.
///
/// So the fade is an overlay gradient in [fadeColor], which paints on top and
/// clips nothing. It needs to know what sits behind it, which is why it is the
/// caller's to supply and why it is optional: `ToolToolbar` has an opaque mica
/// surface and passes its colour, while `DrawingToolbar` has no surface at all —
/// it sits on the page background when docked outside and directly over the
/// board, any colour or an image, when docked inside. There is no honest colour
/// to fade into there, so that bar scrolls without one rather than smearing a
/// wrong one over the board.
class BarScrollArea extends StatefulWidget {

  /// The bar's content — normally the [Flex] holding its groups.
  final Widget child;

  /// The bar's layout axis, which is also the axis it scrolls on.
  final Axis direction;

  /// The colour the ends fade into: the opaque surface this bar paints on.
  ///
  /// Null means the bar has no surface of its own, in which case it scrolls
  /// without a fade — see the class doc.
  final Color? fadeColor;

  const BarScrollArea({
    super.key,
    required this.child,
    this.direction = Axis.horizontal,
    this.fadeColor,
  });

  @override
  State<BarScrollArea> createState() => _BarScrollAreaState();

}

class _BarScrollAreaState extends State<BarScrollArea> {

  /// Whether the content outgrows the room it has, and so has earned the clip
  /// and the fade.
  bool _overflows = false;

  // 0..1 fade strength per end, from how far the content is scrolled past it —
  // so an end that is already flush shows nothing.
  double _leading = 0;
  double _trailing = 0;

  /// Folds the latest metrics into the scroll state.
  ///
  /// Fed from both notification kinds on purpose: [ScrollMetricsNotification]
  /// fires when layout changes the extents (a window resize, a label growing
  /// after a locale switch) and [ScrollNotification] fires while scrolling.
  /// Metrics notifications are dispatched on a microtask, so [setState] is safe
  /// here.
  void _apply(ScrollMetrics metrics) {
    if (metrics.axis != widget.direction) return;
    final overflows = metrics.maxScrollExtent > precisionErrorTolerance;
    final leading = overflows
        ? ((metrics.pixels - metrics.minScrollExtent) / kBarFadeExtent).clamp(0.0, 1.0)
        : 0.0;
    final trailing = overflows
        ? ((metrics.maxScrollExtent - metrics.pixels) / kBarFadeExtent).clamp(0.0, 1.0)
        : 0.0;
    if (overflows == _overflows && leading == _leading && trailing == _trailing) return;
    setState(() {
      _overflows = overflows;
      _leading = leading;
      _trailing = trailing;
    });
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    _apply(notification.metrics);
    return false;
  }

  bool _onScroll(ScrollNotification notification) {
    _apply(notification.metrics);
    return false;
  }

  /// One end's gradient, from [fadeColor] at the edge to nothing inward.
  Widget _fade({required Key key, required bool leading, required Color color, required double strength}) {
    final isHorizontal = widget.direction == Axis.horizontal;
    return Positioned(
      key: key,
      left: isHorizontal ? (leading ? 0 : null) : 0,
      right: isHorizontal ? (leading ? null : 0) : 0,
      top: isHorizontal ? 0 : (leading ? 0 : null),
      bottom: isHorizontal ? 0 : (leading ? null : 0),
      width: isHorizontal ? kBarFadeExtent : null,
      height: isHorizontal ? null : kBarFadeExtent,
      child: IgnorePointer(
        child: Opacity(
          opacity: strength,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isHorizontal
                    ? (leading ? Alignment.centerLeft : Alignment.centerRight)
                    : (leading ? Alignment.topCenter : Alignment.bottomCenter),
                end: isHorizontal
                    ? (leading ? Alignment.centerRight : Alignment.centerLeft)
                    : (leading ? Alignment.bottomCenter : Alignment.topCenter),
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ScrollConfiguration(
      // No scrollbar: a 52px bar has no room for one, and the fade is the
      // affordance instead. Mouse drag is added because there is no scrollbar to
      // fall back on — the bar's own controls are tap-only, so nothing inside
      // competes for the drag.
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: SingleChildScrollView(
        scrollDirection: widget.direction,
        // The relaxed clip below is the only clip in the chain.
        clipBehavior: Clip.none,
        child: widget.child,
      ),
    );

    final fadeColor = widget.fadeColor;
    if (_overflows && fadeColor != null) {
      content = Stack(
        children: [
          // The only non-positioned child, so the Stack shrink-wraps to the
          // viewport. A RenderStack flags overflow from *positioned* children
          // only, so the controls painting past the sides survive this.
          content,
          _fade(key: kBarFadeLeadingKey, leading: true, color: fadeColor, strength: _leading),
          _fade(key: kBarFadeTrailingKey, leading: false, color: fadeColor, strength: _trailing),
        ],
      );
    }

    content = NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: content,
      ),
    );

    if (!_overflows) return content;
    return ClipRect(
      clipper: RelaxedCrossAxisClipper(scrollAxis: widget.direction),
      child: content,
    );
  }

}
