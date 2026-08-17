import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

/// Text whose digits all occupy the same width, so a ticking readout never
/// shifts sideways as the numbers change.
///
/// The idiomatic fix is [FontFeature.tabularFigures], but that only *asks* the
/// shaper for a `tnum` lookup the font has to actually ship — and most fonts do
/// not. Lexend, the app font, carries `ccmp dnom frac liga locl numr` in its
/// GSUB and nothing more, so the request is dropped without a word and its
/// digits keep their proportional advances. At the 48px the clock uses, the gap
/// between its narrowest and widest digit is ~8px, which is what makes the `:`
/// wander.
///
/// So this measures the widest digit *in the caller's own style* and gives each
/// one a box that wide to sit in, centred. Nothing about any particular font is
/// written down here — swapping the app font is safe in either direction, and a
/// font that already renders its digits at a single width (one that ships
/// `tnum`, or a monospace) is detected and handed straight back to a plain
/// [Text].
///
/// **Why boxes and not letter spacing.** Widening each digit by its shortfall
/// via [TextStyle.letterSpacing] is tempting — it stays one paragraph, so
/// `find.text` keeps matching and kerning survives. It gets the digits right,
/// but a glyph *between* two of them lands up to half a shortfall off, because
/// where the shaper puts a glyph depends on the letter spacing of its
/// neighbours as well as its own. That moves the `:` — the whole complaint.
/// Laying the digits out as boxes takes the position away from the shaper
/// entirely, so the answer is the same for every font.
///
/// What that costs:
///
/// - Kerning against a digit is gone, which tabular figures forgo by definition
///   — a fixed advance is the point. Runs of non-digits stay in a single [Text],
///   so their kerning and ligatures survive.
/// - While the digits are boxed the string is spread over several [Text]
///   widgets, so `find.text('12:34')` cannot see it; the readout is reachable by
///   its semantics label, which carries the whole string. Note that widget tests
///   do not normally get that far: the default test font renders every glyph at
///   one width, so they take the uniform-digit path above and see a plain [Text]
///   — the split shows up only under a font that actually needs it.
class TabularText extends StatefulWidget {

  /// Widest digit advance, keyed by everything that can change it.
  ///
  /// Static because several of these tick once a second against the same style
  /// and a miss costs ten [TextPainter] layouts. Cleared on `fontsChange`.
  static final Map<(TextStyle, TextScaler, TextDirection), double> _slotCache = {};

  final String text;

  /// Merged over the ambient [DefaultTextStyle], exactly as [Text] does.
  final TextStyle? style;

  final TextAlign? textAlign;

  const TabularText(this.text, {super.key, this.style, this.textAlign});

  @override
  State<TabularText> createState() => _TabularTextState();

}

class _TabularTextState extends State<TabularText> {

  @override
  void initState() {
    super.initState();
    // Measurements go stale when a font finishes loading after the first frame
    // — the normal case here, since `google_fonts` fetches Lexend at runtime. A
    // `fontsChange` only marks the text renderers dirty, it does not rebuild
    // widgets, so the slots have to be re-measured by hand.
    PaintingBinding.instance.systemFonts.addListener(_handleFontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_handleFontsChanged);
    super.dispose();
  }

  void _handleFontsChanged() {
    TabularText._slotCache.clear();
    if (mounted) setState(() {});
  }

  static bool _isDigit(String char) {
    if (char.length != 1) return false;
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  /// The slot every digit gets, or null when the font already renders them all
  /// at one width and none of this is needed.
  double? _slotWidth(TextStyle style, TextScaler scaler, TextDirection direction) {
    final key = (style, scaler, direction);
    final cached = TabularText._slotCache[key];
    if (cached != null) return cached == 0 ? null : cached;

    final painter = TextPainter(textDirection: direction, textScaler: scaler);
    final advances = <double>[];
    for (var digit = 0; digit <= 9; digit++) {
      painter
        ..text = TextSpan(text: '$digit', style: style)
        ..layout();
      // TextPainter.width rounds up to whole pixels; line metrics do not, and a
      // rounded advance would leave up to a pixel of the jitter in place.
      advances.add(painter.computeLineMetrics().single.width);
    }
    painter.dispose();

    final widest = advances.reduce(math.max);
    final uniform = widest - advances.reduce(math.min) < 0.01;
    TabularText._slotCache[key] = uniform ? 0 : widest;
    return uniform ? null : widest;
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final slot = _slotWidth(style, MediaQuery.textScalerOf(context), Directionality.of(context));
    if (slot == null) {
      return Text(widget.text, style: widget.style, textAlign: widget.textAlign);
    }

    final children = <Widget>[];
    final run = StringBuffer();

    void flushRun() {
      if (run.isEmpty) return;
      children.add(Text(run.toString(), style: style));
      run.clear();
    }

    for (final char in widget.text.characters) {
      if (!_isDigit(char)) {
        run.write(char);
        continue;
      }
      flushRun();
      children.add(
        SizedBox(
          width: slot,
          // Centred by the Text rather than an Align: an Align would grow to the
          // cross-axis constraint and drag the digit off the run's baseline.
          child: Text(char, style: style, textAlign: TextAlign.center),
        ),
      );
    }
    flushRun();

    // Every child carries the same style, so their line boxes are identical and
    // the baselines line up without asking Row to solve for them.
    final row = Row(mainAxisSize: MainAxisSize.min, children: children);
    // The string is read as a whole; the per-digit split is a layout detail.
    final labelled = Semantics(label: widget.text, child: ExcludeSemantics(child: row));

    return switch (widget.textAlign) {
      null => labelled,
      TextAlign.center => Align(heightFactor: 1, child: labelled),
      TextAlign.right || TextAlign.end => Align(
          alignment: AlignmentDirectional.centerEnd,
          heightFactor: 1,
          child: labelled,
        ),
      _ => Align(alignment: AlignmentDirectional.centerStart, heightFactor: 1, child: labelled),
    };
  }

}
