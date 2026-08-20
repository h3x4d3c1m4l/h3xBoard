import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/views/board_screen/components/widgets/rounded_text_highlight.dart';

const _fontSize = 48.0;
const _lineHeight = _fontSize * 1.3;
const _style = TextStyle(fontSize: _fontSize, height: 1.3);

/// Pins every line to the same height regardless of the glyph sizes inside it,
/// so [_paragraph] can vary line *widths* on their own.
const _strut = StrutStyle(fontSize: _fontSize, height: 1.3, forceStrutHeight: true);

/// A paragraph whose lines are [widths] wide, in units of one test glyph.
///
/// The test font draws every glyph as a square of the font size, so a whole
/// number of glyphs can only step a line's width by a whole font size — far more
/// than the few pixels that used to draw a spike. The fractional part of each
/// entry is therefore rendered as a single glyph shrunk to that fraction, which
/// is what buys the sub-pixel control the interesting cases need.
TextPainter _paragraph(List<double> widths, {TextAlign textAlign = TextAlign.left}) {
  final children = <InlineSpan>[];

  for (var i = 0; i < widths.length; i++) {
    if (i > 0) children.add(const TextSpan(text: '\n'));
    children.add(TextSpan(text: 'M' * widths[i].floor()));
    final fraction = widths[i] - widths[i].floor();
    if (fraction > 0) {
      children.add(TextSpan(text: 'M', style: _style.copyWith(fontSize: _fontSize * fraction)));
    }
  }

  return TextPainter(
    text: TextSpan(style: _style, children: children),
    strutStyle: _strut,
    textAlign: textAlign,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 4000);
}

/// The outermost edges any line asks for. Lines are only ever drawn flush with
/// one another, never wider than the widest of them, so the highlight has to
/// stay inside this.
({double left, double right}) _lineBounds(TextPainter painter) {
  final metrics = painter.computeLineMetrics().where((line) => line.width > 0);
  final side = _lineHeight * RoundedTextHighlight.sidePaddingFactor;

  return (
    left: metrics.map((line) => line.left - side).reduce((a, b) => a < b ? a : b),
    right: metrics.map((line) => line.left + line.width + side).reduce((a, b) => a > b ? a : b),
  );
}

void main() {
  group('RoundedTextHighlight', () {
    // The fault this widget was written for: three lines within a few pixels of
    // each other, above a much shorter one. The package it replaced drew the
    // step between the first two lines as a full-radius corner, which came out
    // as a tail pointing off the side of the paragraph.
    test('near-equal lines never draw past the widest line', () {
      final painter = _paragraph([14.1, 14.2, 14.3, 6]);
      final bounds = RoundedTextHighlight.backgroundPath(painter).getBounds();

      expect(bounds.right, moreOrLessEquals(_lineBounds(painter).right, epsilon: 0.5));
    });

    test('no line width combination draws past the widest line', () {
      // Steps of a tenth of a glyph sweep straight through the range where the
      // corner radius is wider than the step it has to fit in.
      for (var second = 10.0; second <= 15.0; second += 0.1) {
        for (final third in [second - 0.4, second + 0.4, 6.0, 15.0]) {
          final painter = _paragraph([14, second, third]);
          final bounds = RoundedTextHighlight.backgroundPath(painter).getBounds();
          final lines = _lineBounds(painter);

          expect(
            bounds.right,
            lessThanOrEqualTo(lines.right + 0.5),
            reason: 'widths 14/$second/$third reach past the widest line',
          );
          expect(
            bounds.left,
            greaterThanOrEqualTo(lines.left - 0.5),
            reason: 'widths 14/$second/$third reach past the leftmost line',
          );
        }
      }
    });

    // A centred paragraph staggers both edges, so the left side has to be
    // treated exactly like the right one.
    test('centred text keeps both edges inside the widest line', () {
      for (var second = 10.0; second <= 15.0; second += 0.1) {
        final painter = _paragraph([14, second, 13.5], textAlign: TextAlign.center);
        final bounds = RoundedTextHighlight.backgroundPath(painter).getBounds();
        final lines = _lineBounds(painter);

        expect(bounds.right, lessThanOrEqualTo(lines.right + 0.5), reason: 'width $second');
        expect(bounds.left, greaterThanOrEqualTo(lines.left - 0.5), reason: 'width $second');
      }
    });

    test('lines close enough together are drawn flush', () {
      final painter = _paragraph([14.1, 14.2, 14.3]);
      final path = RoundedTextHighlight.backgroundPath(painter);
      final right = _lineBounds(painter).right;
      final metrics = painter.computeLineMetrics();

      // A point just inside the widest edge, on the vertical middle of each line.
      for (final line in metrics) {
        final y = line.baseline - line.ascent + _lineHeight / 2;
        expect(path.contains(Offset(right - 1, y)), isTrue, reason: 'line ${line.lineNumber} is not flush');
      }
    });

    test('a staircase keeps its steps rather than collapsing to the widest line', () {
      // Each step is well clear of the snapping tolerance, so nothing merges.
      final painter = _paragraph([4, 8, 12, 16]);
      final path = RoundedTextHighlight.backgroundPath(painter);
      final metrics = painter.computeLineMetrics();
      final side = _lineHeight * RoundedTextHighlight.sidePaddingFactor;

      for (final line in metrics) {
        final y = line.baseline - line.ascent + _lineHeight / 2;
        expect(path.contains(Offset(line.width + side - 1, y)), isTrue,
            reason: 'line ${line.lineNumber} is narrower than its own text');
        expect(path.contains(Offset(line.width + side + 2, y)), isFalse,
            reason: 'line ${line.lineNumber} was widened to a neighbour it is nowhere near');
      }
    });

    test('a blank line breaks the highlight in two', () {
      final painter = TextPainter(
        text: const TextSpan(text: 'MMMM\n\nMMMM', style: _style),
        strutStyle: _strut,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 4000);
      final path = RoundedTextHighlight.backgroundPath(painter);

      // The middle of the blank line, horizontally inside both paragraphs.
      expect(path.contains(Offset(_fontSize, _lineHeight * 1.5)), isFalse);
      expect(path.contains(Offset(_fontSize, _lineHeight * 0.5)), isTrue);
      expect(path.contains(Offset(_fontSize, _lineHeight * 2.5)), isTrue);
    });

    test('an empty paragraph paints nothing', () {
      final painter = TextPainter(text: const TextSpan(text: '', style: _style), textDirection: TextDirection.ltr)
        ..layout(maxWidth: 4000);

      expect(RoundedTextHighlight.backgroundPath(painter).computeMetrics().isEmpty, isTrue);
    });
  });
}
