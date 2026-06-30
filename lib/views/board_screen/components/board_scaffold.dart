import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/models/app_settings_enums.dart';

/// Gap between an outside (docked) bar and the board edge it sits against.
const double _kBarGap = 8;

/// One bar docked around (or floating over) the board.
class DockedBar {

  /// The bar widget. Its own layout axis should already match [position].axis.
  final Widget bar;

  /// Which edge the bar sits against.
  final BarPosition position;

  /// `true` floats the bar over the board (overlay); `false` reserves layout
  /// space for it beside the board.
  final bool inside;

  const DockedBar({required this.bar, required this.position, required this.inside});

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

  Alignment _alignmentFor(BarPosition position) => switch (position) {
    BarPosition.left => Alignment.centerLeft,
    BarPosition.right => Alignment.centerRight,
    BarPosition.top => Alignment.topCenter,
    BarPosition.bottom => Alignment.bottomCenter,
  };

  @override
  Widget build(BuildContext context) {
    List<Widget> at(BarPosition pos, {required bool inside}) => bars
        .where((b) => b.inside == inside && b.position == pos)
        .map((b) => b.bar)
        .toList();

    // Ring 1: inside (overlay) bars float over the board, aligned to their edge.
    final insideBars = bars.where((b) => b.inside).toList();
    Widget content = center;
    if (insideBars.isNotEmpty) {
      content = Stack(
        children: [
          Positioned.fill(child: center),
          for (final b in insideBars)
            Align(
              alignment: _alignmentFor(b.position),
              child: b.bar,
            ),
        ],
      );
    }

    // Ring 2: outside left/right bars sit beside the board. The board area is
    // aspect-locked (16:9) and shrink-wraps via Flexible (loose fit), so the bar
    // hugs the board's real edge instead of the far screen edge; centering the
    // row keeps the [bar, board] group together rather than spreading them apart.
    final left = at(BarPosition.left, inside: false);
    final right = at(BarPosition.right, inside: false);
    if (left.isNotEmpty || right.isNotEmpty) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: _kBarGap,
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
        spacing: _kBarGap,
        children: [
          ...top,
          Flexible(child: content),
          ...bottom,
        ],
      );
    }

    // The board column shrink-wraps (mainAxisSize.min), so a bare board with no
    // outside bars would otherwise pin to the top-left — keep it centered. Inside
    // overlays (Stack) and the outside rings already center their content.
    final hasOutside = left.isNotEmpty || right.isNotEmpty || top.isNotEmpty || bottom.isNotEmpty;
    if (!hasOutside && insideBars.isEmpty) {
      content = Center(child: content);
    }

    return content;
  }

}
