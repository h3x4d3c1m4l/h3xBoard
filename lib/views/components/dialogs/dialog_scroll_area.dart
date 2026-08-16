import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:scroll_edge_hint/scroll_edge_hint.dart';

/// How far [DialogScrollArea] relaxes its clip sideways — see
/// [RelaxedHorizontalClipper].
const double kDialogScrollBleed = 8;

/// Keeps a scrollable's vertical bounds exactly and relaxes them [bleed] px to
/// either side.
///
/// A vertical viewport clips to its own box as soon as it has something to
/// scroll, which is what stops rows painting over the title and the actions bar
/// — that part is wanted. The sideways half is not: a control's
/// [ContinuousRectangleBorder] strokes half its width *outside* the path it
/// draws, so a clip flush with the content shaves the left and right border off
/// every text field inside it.
///
/// Handing the viewport [Clip.none] and this in its place keeps the clipping
/// that matters and drops the clipping that only ever cut borders. It leaves
/// layout completely alone, which is the point: the alternative is for every
/// caller to borrow a few pixels off its own padding and hand them back as inner
/// padding, and that is a contract three call sites can get wrong.
class RelaxedHorizontalClipper extends CustomClipper<Rect> {

  /// How far the clip reaches past each side.
  final double bleed;

  const RelaxedHorizontalClipper({this.bleed = kDialogScrollBleed});

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-bleed, 0, size.width + bleed, size.height);

  @override
  bool shouldReclip(RelaxedHorizontalClipper oldClipper) => oldClipper.bleed != bleed;

}

/// Makes dialog content scroll once it outgrows the room the dialog has — and
/// only then.
///
/// Both dialog shells lay their content out inside a *loose* [Flexible], so this
/// is handed `minHeight: 0, maxHeight: whatever is left`; a
/// [SingleChildScrollView] shrink-wraps to `min(childHeight, maxHeight)` and
/// [ScrollEdgeHint]'s [Stack] shrink-wraps with it. Content that already fits
/// therefore keeps exactly the height it had, and the edge hints stay at opacity
/// zero because there is nothing to scroll.
///
/// One thing to know before wrapping content in this: a [Scrollable]'s vertical
/// drag recognizer accepts at `kTouchSlop` (18px) while a pan recognizer needs
/// `kPanSlop` (36px), so a drag surface *inside* a scroll view loses the gesture
/// arena on vertical drags. Content holding one (the colour picker's
/// saturation/value field) must opt out rather than be wrapped.
class DialogScrollArea extends StatefulWidget {

  /// The content to scroll.
  final Widget child;

  /// What the top/bottom edge hints fade into — the surface the dialog paints
  /// behind this content, so rows dissolve into the edge instead of stopping at
  /// a visible line. The two shells have different surfaces (an accent-tinted
  /// one for [ThemableContentDialog], white for `ThemablePanelDialog`), which is
  /// why there is no default.
  final Color fadeColor;

  /// Inner padding for the scrolled content.
  ///
  /// Defaults to none: fluent's [Scrollbar] overlays the content rather than
  /// taking space, so only the panels that want their content to clear the
  /// thumb pass a gutter.
  final EdgeInsetsGeometry padding;

  const DialogScrollArea({
    super.key,
    required this.child,
    required this.fadeColor,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<DialogScrollArea> createState() => _DialogScrollAreaState();

}

class _DialogScrollAreaState extends State<DialogScrollArea> {

  /// Room at each end of the scroll, so the first and last row come to rest
  /// clear of the edge instead of flush against it.
  static const EdgeInsets _endGaps = EdgeInsets.only(
    top: kScrollStartPadding,
    bottom: kScrollEndPadding,
  );

  /// Whether the content outgrows the room it has, and so has earned [_endGaps].
  ///
  /// They have to be conditional rather than always applied: they are spent on
  /// the scrollable's own extent, and a [SingleChildScrollView] sizes itself to
  /// that extent — so on a dialog that fits, an unconditional gap is not a
  /// scroll affordance at all, just dead space around every two-line
  /// confirmation in the app.
  bool _scrolls = false;

  /// Tracks whether the content overflows, from the metrics the scrollable
  /// reports after each layout (dispatched on a microtask, so setState is safe
  /// here).
  ///
  /// It measures the extent *without* the gaps this widget may already be
  /// adding, which is what stops the answer feeding back on itself: turning them
  /// on cannot make a scrollable stop scrolling, and turning them off cannot
  /// make one start, so the state settles in one step either way.
  bool _onMetrics(ScrollMetricsNotification notification) {
    final added = _scrolls ? _endGaps.vertical : 0;
    final scrolls = notification.metrics.maxScrollExtent - added > precisionErrorTolerance;
    if (scrolls != _scrolls) setState(() => _scrolls = scrolls);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      // Outermost, and nothing between here and the viewport clips: a Stack only
      // flags overflow from its *positioned* children, and the Scrollbar paints
      // through. So this is the one clip in the chain.
      clipper: const RelaxedHorizontalClipper(),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetrics,
        child: ScrollEdgeHint.builder(
          backgroundColor: widget.fadeColor,
          extent: 24,
          builder: (context, controller) => Scrollbar(
            controller: controller,
            // Nudge the thumb closer to the dialog edge.
            style: const ScrollbarThemeData(
              padding: EdgeInsetsDirectional.only(end: 1, top: 4, bottom: 4),
            ),
            // Suppress the platform/default scrollbar (notably on web) so it
            // doesn't double up with this fluent one.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                controller: controller,
                // Its own clip is handed to the ClipRect above, which keeps the
                // vertical bounds and relaxes the sideways ones.
                clipBehavior: Clip.none,
                // The gaps ride on the scrollable's own extent, so the first and
                // last row come to rest clear of the edge rather than flush.
                padding: _scrolls ? widget.padding.add(_endGaps) : widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }

}
