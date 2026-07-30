import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/models/app_settings_enums.dart';

/// Gap between an outside (docked) bar and the board edge it sits against.
const double _kBarGap = 8;

/// Inset between an inside (floating) bar and the board edge it hugs. Larger than
/// [_kBarGap] because the bar sits *on* the board here, so it needs breathing room
/// against the drawable area instead of merely a seam against the board's border.
const double _kInsideBarInset = 16;

/// How long a bar takes to slip away towards its edge, or to come back.
const Duration _kBarVisibilityDuration = Duration(milliseconds: 250);

/// The direction a bar leaves in when hidden: straight out through the edge it
/// is docked against, as a fraction of the bar's own size.
Offset _hideDirectionFor(BarPosition position) => switch (position) {
  BarPosition.left => const Offset(-1, 0),
  BarPosition.right => const Offset(1, 0),
  BarPosition.top => const Offset(0, -1),
  BarPosition.bottom => const Offset(0, 1),
};

/// Where a bar sits within the space it is given: against its own edge.
Alignment _alignmentFor(BarPosition position) => switch (position) {
  BarPosition.left => Alignment.centerLeft,
  BarPosition.right => Alignment.centerRight,
  BarPosition.top => Alignment.topCenter,
  BarPosition.bottom => Alignment.bottomCenter,
};

/// One bar docked around (or floating over) the board.
class DockedBar {

  /// The bar widget. Its own layout axis should already match [position].axis.
  final Widget bar;

  /// Which edge the bar sits against.
  final BarPosition position;

  /// `true` floats the bar over the board (overlay); `false` reserves layout
  /// space for it beside the board.
  final bool inside;

  /// `false` slides the bar out through its edge and fades it away — used while
  /// the laser pointer is armed, when the board is look-don't-touch. An outside
  /// bar gives its reserved space back as it goes, so the board grows into it.
  final bool visible;

  const DockedBar({required this.bar, required this.position, required this.inside, this.visible = true});

}

/// Lays out the board with its bars (color selection bar, tool bar) placed
/// according to user settings. Outside bars reserve space on their edge; inside
/// bars float over the board, aligned to their edge.
///
/// Edges are composed in three rings: inside overlays first (a [Stack] over the
/// [center]), then the left/right outside bars (a [Row]), then the top/bottom
/// outside bars (a [Column]).
class BoardScaffold extends StatelessWidget {

  /// The central content (sub-board tabs + the board canvas).
  final Widget center;

  /// The bars to place. Realistic configs dock them to different edges; bars on
  /// the same edge simply stack in list order.
  final List<DockedBar> bars;

  const BoardScaffold({super.key, required this.center, required this.bars});

  Widget _slot(DockedBar bar) => _BarSlot(
    position: bar.position,
    inside: bar.inside,
    visible: bar.visible,
    child: bar.bar,
  );

  @override
  Widget build(BuildContext context) {
    List<Widget> at(BarPosition pos, {required bool inside}) => bars
        .where((b) => b.inside == inside && b.position == pos)
        .map(_slot)
        .toList();

    // Ring 1: inside (overlay) bars float over the board, aligned to their edge.
    // `center` (the aspect-locked board) is the Stack's only non-positioned
    // child, so the Stack shrink-wraps to the board's real 16:9 size; the inside
    // bars are overlaid within those bounds (Positioned.fill + Align) so they hug
    // the board's real edges rather than the far screen edges. The bars carry no
    // outer padding of their own — this scaffold owns all bar spacing, so every
    // bar sits the same distance from the board no matter which one it is.
    final insideBars = bars.where((b) => b.inside).toList();
    Widget content = center;
    if (insideBars.isNotEmpty) {
      content = Stack(
        children: [
          center,
          for (final b in insideBars)
            Positioned.fill(
              child: Align(
                alignment: _alignmentFor(b.position),
                child: _slot(b),
              ),
            ),
        ],
      );
    }

    // Ring 2: outside left/right bars sit beside the board. The board area is
    // aspect-locked (16:9) and shrink-wraps via Flexible (loose fit), so the bar
    // hugs the board's real edge instead of the far screen edge; centering the
    // row keeps the [bar, board] group together rather than spreading them apart.
    // The gap to the board is the slot's own padding, not the row's spacing, so
    // that it collapses along with the bar when the bar is hidden.
    final left = at(BarPosition.left, inside: false);
    final right = at(BarPosition.right, inside: false);
    if (left.isNotEmpty || right.isNotEmpty) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...left,
          Flexible(child: content),
          ...right,
        ],
      );
    }

    // Ring 3: outside top/bottom bars sit above/below everything — same approach
    // as Ring 2, so the bar hugs the board's real top/bottom edge.
    final top = at(BarPosition.top, inside: false);
    final bottom = at(BarPosition.bottom, inside: false);
    if (top.isNotEmpty || bottom.isNotEmpty) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...top,
          Flexible(child: content),
          ...bottom,
        ],
      );
    }

    // The board shrink-wraps to its 16:9 size, so with no outside bars it would
    // otherwise pin to the top-left — keep it centered. The outside rings already
    // center their content via mainAxisAlignment.
    final hasOutside = left.isNotEmpty || right.isNotEmpty || top.isNotEmpty || bottom.isNotEmpty;
    if (!hasOutside) {
      content = Center(child: content);
    }

    return content;
  }

}

/// The space one bar occupies: its spacing against the board, and the animation
/// that takes it away (out through its own edge, fading as it goes) when
/// [visible] turns false — then brings it back when it turns true again.
///
/// An outside bar hands its reserved space back to the board as it leaves, so
/// the board grows to fill the width it no longer needs; an inside bar floats
/// over the board and has no space to give.
class _BarSlot extends StatelessWidget {

  final Widget child;

  /// The edge the bar is docked against — it sits there, and leaves that way.
  final BarPosition position;

  /// Whether the bar floats over the board (see [DockedBar.inside]).
  final bool inside;

  final bool visible;

  const _BarSlot({required this.child, required this.position, required this.inside, required this.visible});

  /// The bar's spacing against the board. An inside bar is inset on all sides —
  /// it sits *on* the drawable area, so it needs room on every side it might
  /// touch. An outside bar only needs the seam on the side facing the board;
  /// its other sides are the page background, spaced by the page's own padding.
  EdgeInsets get _spacing => inside
      ? const EdgeInsets.all(_kInsideBarInset)
      : switch (position) {
          BarPosition.left => const EdgeInsets.only(right: _kBarGap),
          BarPosition.right => const EdgeInsets.only(left: _kBarGap),
          BarPosition.top => const EdgeInsets.only(bottom: _kBarGap),
          BarPosition.bottom => const EdgeInsets.only(top: _kBarGap),
        };

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // No `begin`: the bar's first build settles on its current visibility
      // instead of animating in on arrival.
      tween: Tween<double>(end: visible ? 1 : 0),
      duration: _kBarVisibilityDuration,
      curve: Curves.easeInOutCubic,
      // The bar is stopped from taking taps the moment it starts leaving, rather
      // than when it finishes — a half-faded button is not something to hit.
      child: IgnorePointer(
        ignoring: !visible,
        child: Padding(padding: _spacing, child: child),
      ),
      builder: (context, t, child) {
        final bar = Opacity(
          opacity: t,
          child: FractionalTranslation(
            translation: _hideDirectionFor(position) * (1 - t),
            child: child,
          ),
        );
        if (inside) return bar;

        // Give the reserved space back in step with the fade. The slot keeps the
        // *board-facing* edge of the bar pinned (hence the opposite alignment)
        // while shrinking away from it, so the bar tracks the board edge as it
        // advances rather than sliding along under it.
        //
        // Both factors are set, never left null: a null factor makes Align fill
        // the space it is offered instead of wrapping the bar, and a slot that
        // fills its cross axis stretches the row/column it sits in to the full
        // height/width of the board area — which pushes any bar docked on the
        // *other* ring away from the board edge it is supposed to hug.
        final consumesWidth = position.axis == Axis.vertical;
        return Align(
          alignment: -_alignmentFor(position),
          widthFactor: consumesWidth ? t : 1,
          heightFactor: consumesWidth ? 1 : t,
          child: bar,
        );
      },
    );
  }

}
