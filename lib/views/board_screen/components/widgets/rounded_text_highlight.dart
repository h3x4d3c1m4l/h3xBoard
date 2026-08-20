import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Text on a rounded highlight, the way a marker pen leaves it: one rounded box
/// per line, merged into a single shape wherever the lines touch.
///
/// This replaces the `rounded_background_text` package, whose painter draws a
/// spike out of the side of a paragraph — a speech-bubble tail — whenever two
/// neighbouring lines happen to end within a corner radius of each other. Two
/// things in it combine to produce that, and both are ruled out here by
/// construction rather than patched:
///
///  * it evens out near-equal line widths by copying each line's width from the
///    line below it, but does so top-down, so a line is matched to its
///    neighbour's width *before* that neighbour has itself been widened. Three
///    similar lines are left with a few pixels of residual difference;
///  * its corners are then drawn at their full radius regardless of how little
///    horizontal room the step between two lines leaves them, so those few
///    pixels of difference are drawn as a corner tens of pixels wide, pointing
///    away from the paragraph.
///
/// Here the highlight is the **union of one rectangle per line**, and every
/// corner of that outline is rounded by one rule: the radius is never more than
/// half of either edge meeting at it. A one-pixel step therefore draws a
/// half-pixel corner instead of a spike, and there is no case left to get wrong.
///
/// Two pieces of Flutter behaviour this leans on:
///
///  * [TextPainter.computeLineMetrics] reports `left`/`width` *after* alignment,
///    so a centred paragraph gives staggered left edges as well as right ones,
///    and both sides need the same treatment;
///  * consecutive lines report `baseline - ascent` tops that meet exactly, so
///    the per-line rectangles only overlap by the [bottomPaddingFactor] tail
///    each one is given. That overlap is what makes the union a single shape
///    instead of a stack of separate boxes.
class RoundedTextHighlight extends StatelessWidget {

  /// How far the highlight bleeds *outside* the text box, as factors of the line
  /// height. The painter draws in the text's own coordinate space and paints
  /// over the edges of it, so a caller that wants the highlight unclipped has to
  /// add these back as real padding — see [paddingFor].
  static const double sidePaddingFactor = 0.3;
  static const double topPaddingFactor = 0.3;
  static const double bottomPaddingFactor = 0.175 / 2;

  /// Corner radius, as a factor of the line height. Matches what the package
  /// resolved its maximum radius of 20 to (`height * 20 / 35`), so the shape is
  /// unchanged apart from the fault this widget exists to fix.
  static const double _cornerRadiusFactor = 20 / 35;

  /// Neighbouring lines whose edges land within this much of each other (again a
  /// factor of the line height) are drawn flush instead of a few pixels apart —
  /// a hairline step in a highlight reads as a rendering fault, not as text.
  /// A line only ever moves *outwards* to meet its neighbour, so its own glyphs
  /// can never end up outside their highlight.
  static const double _snapFactor = 20 / 35;

  /// Two positions closer together than this are the same corner.
  static const double _epsilon = 0.01;

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final Color backgroundColor;

  const RoundedTextHighlight({
    super.key,
    required this.text,
    required this.style,
    required this.textAlign,
    required this.backgroundColor,
  });

  /// The insets the highlight paints outside a text box whose lines are
  /// [lineHeight] tall.
  ///
  /// Only [bottomPaddingFactor] is exact: the highlight's top edge sits on the
  /// first line's own top, which is at or a hair above the text box, so
  /// [topPaddingFactor] is deliberate slack. Overshooting there only adds
  /// invisible margin; undershooting would clip the highlight.
  static EdgeInsets paddingFor(double lineHeight) => EdgeInsets.only(
        left: lineHeight * sidePaddingFactor,
        right: lineHeight * sidePaddingFactor,
        top: lineHeight * topPaddingFactor,
        bottom: lineHeight * bottomPaddingFactor,
      );

  /// Lays a paragraph out the way this widget paints it.
  ///
  /// Callers that size themselves to the text measure through here too, so what
  /// is measured and what is painted cannot drift apart.
  static TextPainter layoutPainter({
    required String text,
    required TextStyle style,
    required TextAlign textAlign,
    double minWidth = 0,
    required double maxWidth,
  }) =>
      TextPainter(
        text: TextSpan(text: text, style: style),
        textAlign: textAlign,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(minWidth: minWidth, maxWidth: maxWidth);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Laid out to the box we were given rather than to the text's own width:
        // `textAlign` positions each line within that box, and the highlight has
        // to follow the glyphs.
        final painter = layoutPainter(
          text: text,
          style: style,
          textAlign: textAlign,
          minWidth: constraints.minWidth,
          maxWidth: constraints.maxWidth,
        );

        return CustomPaint(
          isComplex: true,
          size: Size(
            painter.width.clamp(0, constraints.maxWidth),
            painter.height.clamp(0, constraints.maxHeight),
          ),
          painter: _RoundedTextHighlightPainter(text: painter, backgroundColor: backgroundColor),
        );
      },
    );
  }

  /// One rectangle per line, split into runs at blank lines — a blank line
  /// breaks the highlight in two rather than joining the paragraphs through a
  /// sliver of nothing. The line height rides along because both the corner
  /// radius and the snapping tolerance are proportional to it, and the box is
  /// slightly taller than the line it holds.
  static List<List<_HighlightLine>> _runs(TextPainter text) {
    final runs = <List<_HighlightLine>>[];
    var run = <_HighlightLine>[];

    for (final line in text.computeLineMetrics()) {
      if (line.width == 0) {
        if (run.isNotEmpty) runs.add(run);
        run = <_HighlightLine>[];
        continue;
      }
      final side = line.height * sidePaddingFactor;
      final top = line.baseline - line.ascent;
      run.add((
        box: Rect.fromLTRB(
          line.left - side,
          top,
          line.left + line.width + side,
          // The tail below each line is what overlaps it with the next one.
          top + line.height + line.height * bottomPaddingFactor,
        ),
        lineHeight: line.height,
      ));
    }
    if (run.isNotEmpty) runs.add(run);

    return runs.map(_snapNearEqualEdges).toList();
  }

  /// Draws neighbouring lines whose edges land within [_snapFactor] of each
  /// other flush, on their outermost edge — a hairline step in a highlight reads
  /// as a rendering fault, not as text.
  ///
  /// Left and right edges are grouped independently, because a centred paragraph
  /// staggers both. A line joins the group it neighbours only while the whole
  /// group still spans less than the tolerance, so a gradual staircase keeps its
  /// steps instead of collapsing line by line into one very wide block. Edges
  /// only ever move *outwards*, so a line's glyphs can never end up outside
  /// their own highlight.
  static List<_HighlightLine> _snapNearEqualEdges(List<_HighlightLine> lines) {
    final lefts = _snappedEdges(lines, (line) => line.box.left, math.min);
    final rights = _snappedEdges(lines, (line) => line.box.right, math.max);

    return [
      for (var i = 0; i < lines.length; i++)
        (
          box: Rect.fromLTRB(lefts[i], lines[i].box.top, rights[i], lines[i].box.bottom),
          lineHeight: lines[i].lineHeight,
        ),
    ];
  }

  /// One edge of every line, with each run of near-equal ones replaced by the
  /// [outward]-most edge in that run.
  static List<double> _snappedEdges(
    List<_HighlightLine> lines,
    double Function(_HighlightLine line) edgeOf,
    double Function(double a, double b) outward,
  ) {
    final edges = lines.map(edgeOf).toList(growable: false);
    final snapped = List<double>.of(edges);

    var start = 0;
    var lowest = edges.first;
    var highest = edges.first;

    void settle(int end) {
      final shared = outward(lowest, highest);
      for (var i = start; i < end; i++) {
        snapped[i] = shared;
      }
    }

    for (var i = 1; i < edges.length; i++) {
      final low = math.min(lowest, edges[i]);
      final high = math.max(highest, edges[i]);

      if (high - low <= lines[i].lineHeight * _snapFactor) {
        lowest = low;
        highest = high;
      } else {
        settle(i);
        start = i;
        lowest = highest = edges[i];
      }
    }
    settle(edges.length);

    return snapped;
  }

  /// Where the union's right edge steps from [upper] to [lower]. The wider of
  /// the two covers the whole band the rectangles overlap in, so the step
  /// happens at that line's own bound: the lower line's top when it is the wider
  /// one, the upper line's bottom when it is.
  static double _rightStep(Rect upper, Rect lower) => lower.right > upper.right ? lower.top : upper.bottom;

  /// The same for the left edge, where "wider" means reaching further left.
  static double _leftStep(Rect upper, Rect lower) => upper.left < lower.left ? upper.bottom : lower.top;

  /// The outline of one run, clockwise from its top-right corner: down the right
  /// edge, across the bottom, up the left edge.
  static List<Offset> _outline(List<_HighlightLine> lines) {
    final boxes = lines.map((line) => line.box).toList(growable: false);
    final corners = <Offset>[];

    for (var i = 0; i < boxes.length; i++) {
      final top = i == 0 ? boxes[i].top : _rightStep(boxes[i - 1], boxes[i]);
      final bottom = i == boxes.length - 1 ? boxes[i].bottom : _rightStep(boxes[i], boxes[i + 1]);
      corners
        ..add(Offset(boxes[i].right, top))
        ..add(Offset(boxes[i].right, bottom));
    }

    for (var i = boxes.length - 1; i >= 0; i--) {
      final bottom = i == boxes.length - 1 ? boxes[i].bottom : _leftStep(boxes[i], boxes[i + 1]);
      final top = i == 0 ? boxes[i].top : _leftStep(boxes[i - 1], boxes[i]);
      corners
        ..add(Offset(boxes[i].left, bottom))
        ..add(Offset(boxes[i].left, top));
    }

    return corners;
  }

  /// Adds [corners] to [path] as a closed shape with every corner filleted.
  ///
  /// The radius at a corner is capped at half of each edge meeting there, so two
  /// neighbouring corners can never eat into the same half of an edge and the
  /// curve can never reach past the corner it is rounding. That cap is the only
  /// thing standing between a narrow step and a spike, and it applies to convex
  /// and concave corners alike — a quadratic through the corner point rounds
  /// both, it just bulges the other way.
  static void _addFilleted(Path path, List<Offset> corners, double radius) {
    final points = _turningPoints(corners);
    if (points.isEmpty) return;

    for (var i = 0; i < points.length; i++) {
      final corner = points[i];
      final previous = points[(i - 1 + points.length) % points.length];
      final next = points[(i + 1) % points.length];

      final toPrevious = previous - corner;
      final toNext = next - corner;
      final r = math.min(radius, math.min(toPrevious.distance, toNext.distance) / 2);

      final from = corner + toPrevious * (r / toPrevious.distance);
      final to = corner + toNext * (r / toNext.distance);

      if (i == 0) {
        path.moveTo(from.dx, from.dy);
      } else {
        path.lineTo(from.dx, from.dy);
      }
      path.quadraticBezierTo(corner.dx, corner.dy, to.dx, to.dy);
    }

    path.close();
  }

  /// The corners of [corners] that actually turn.
  ///
  /// Lines drawn flush hand over to each other mid-edge, which leaves a point
  /// sitting in the middle of a straight run. Left in, it would cap the radius
  /// of the real corners either side of it at half the distance to a point that
  /// is not a corner, quietly flattening them.
  static List<Offset> _turningPoints(List<Offset> corners) {
    final points = <Offset>[];
    for (final corner in corners) {
      if (points.isEmpty || (points.last - corner).distance > _epsilon) points.add(corner);
    }
    // The walk starts and ends on the same corner where a run is a plain box.
    if (points.length > 1 && (points.first - points.last).distance <= _epsilon) points.removeLast();
    if (points.length < 3) return const [];

    final turning = [
      for (var i = 0; i < points.length; i++)
        if (_turns(points[(i - 1 + points.length) % points.length], points[i], points[(i + 1) % points.length]))
          points[i],
    ];

    return turning.length < 3 ? const [] : turning;
  }

  /// Whether the walk changes direction at [corner]. Every edge here is axis
  /// aligned and both of a straight run's edges are built from the same `double`,
  /// so a point that does not turn cross-products to exactly zero.
  static bool _turns(Offset previous, Offset corner, Offset next) {
    final into = corner - previous;
    final outOf = next - corner;

    return (into.dx * outOf.dy - into.dy * outOf.dx).abs() > _epsilon;
  }

  /// The highlight behind [text], in the text's own coordinate space.
  @visibleForTesting
  static Path backgroundPath(TextPainter text) {
    final path = Path();

    for (final run in _runs(text)) {
      _addFilleted(path, _outline(run), run.first.lineHeight * _cornerRadiusFactor);
    }

    return path;
  }

}

/// One line's highlight box, plus the line height the radii are derived from.
typedef _HighlightLine = ({Rect box, double lineHeight});

class _RoundedTextHighlightPainter extends CustomPainter {

  final TextPainter text;
  final Color backgroundColor;

  const _RoundedTextHighlightPainter({required this.text, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      RoundedTextHighlight.backgroundPath(text),
      Paint()..color = backgroundColor,
    );
    text.paint(canvas, Offset.zero);
  }

  @override
  bool hitTest(Offset position) => RoundedTextHighlight.backgroundPath(text).contains(position);

  @override
  bool shouldRepaint(_RoundedTextHighlightPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.backgroundColor != backgroundColor;

}
