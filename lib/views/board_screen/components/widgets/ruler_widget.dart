import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// A single-edged measuring ruler (max 30 cm). The unit setting switches the drawn
// graduations between cm/mm and inches/sixteenths; the "match the squares" setting
// is handled outside the widget by locking the board scale (see [rulerMatchScale]).
class _RulerWidget extends StatelessWidget {

  // 30 cm long at the baseline cm-to-canvas ratio; a thin bar 3 cm tall.
  static const Size naturalSize = Size(30 * kRulerPxPerCm, 3 * kRulerPxPerCm);

  final RulerUnit unit;

  const _RulerWidget({required this.unit});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: naturalSize, painter: _RulerPainter(unit));
  }

}

class _RulerPainter extends CustomPainter {

  static const Color _barColor = Color(0x40FFC107);
  static const Color _inkColor = Color(0xFF243B53);

  final RulerUnit unit;

  const _RulerPainter(this.unit);

  @override
  void paint(Canvas canvas, Size size) {
    // Bar body: translucent so the board and drawings show through while measuring.
    final body = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas
      ..drawRRect(body, Paint()..color = _barColor)
      ..drawRRect(
        body,
        Paint()
          ..color = _inkColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );

    final tick = Paint()
      ..color = _inkColor
      ..strokeWidth = 1;

    if (unit == RulerUnit.cm) {
      _paintCm(canvas, size, tick);
    } else {
      _paintInch(canvas, size, tick);
    }

    _paintUnitLabel(canvas, size);
  }

  void _paintCm(Canvas canvas, Size size, Paint tick) {
    const pxPerMm = kRulerPxPerCm / 10;
    for (int i = 0; i * pxPerMm <= size.width; i++) {
      final x = i * pxPerMm;
      final len = i % 10 == 0 ? 40.0 : (i % 5 == 0 ? 26.0 : 16.0);
      canvas.drawLine(Offset(x, 0), Offset(x, len), tick);
      if (i % 10 == 0) _paintNumber(canvas, size, x, '${i ~/ 10}');
    }
  }

  void _paintInch(Canvas canvas, Size size, Paint tick) {
    const pxPerInch = 2.54 * kRulerPxPerCm;
    const pxPer16th = pxPerInch / 16;
    for (int j = 0; j * pxPer16th <= size.width; j++) {
      final x = j * pxPer16th;
      final double len;
      if (j % 16 == 0) {
        len = 40;
      } else if (j % 8 == 0) {
        len = 30;
      } else if (j % 4 == 0) {
        len = 24;
      } else if (j.isEven) {
        len = 18;
      } else {
        len = 12;
      }
      canvas.drawLine(Offset(x, 0), Offset(x, len), tick);
      if (j % 16 == 0) _paintNumber(canvas, size, x, '${j ~/ 16}');
    }
  }

  // A graduation number, centred under its tick and clamped to stay on the bar.
  void _paintNumber(Canvas canvas, Size size, double x, String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: _inkColor, fontSize: 22)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final tx = (x - tp.width / 2).clamp(2.0, size.width - tp.width - 2);
    tp.paint(canvas, Offset(tx, 46));
  }

  void _paintUnitLabel(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: unit == RulerUnit.cm ? 'cm' : 'in',
        style: const TextStyle(color: _inkColor, fontSize: 24, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width - 16, size.height - tp.height - 14));
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.unit != unit;

}

class RulerWidgetDescriptor extends BoardWidgetDescriptor {

  static const RulerWidgetDescriptor instance = RulerWidgetDescriptor._();
  const RulerWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.ruler;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_ruler;

  @override
  Size naturalSize(BoardWidgetConfig config) => _RulerWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const RulerConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as RulerConfig;
    return _RulerWidget(unit: c.unit);
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as RulerConfig;
    final l = context.localizations;

    RadioMenuFlyoutItem<RulerUnit> unitItem(RulerUnit unit, String label) {
      return RadioMenuFlyoutItem<RulerUnit>(
        value: unit,
        groupValue: c.unit,
        text: Text(label),
        // Switching unit invalidates the current match mapping; reset to none when so.
        onChanged: (u) {
          final match = rulerMatchesFor(u).contains(c.match) ? c.match : RulerGridMatch.none;
          onChange(c.copyWith(unit: u, match: match));
        },
      );
    }

    RadioMenuFlyoutItem<RulerGridMatch> matchItem(RulerGridMatch match) {
      return RadioMenuFlyoutItem<RulerGridMatch>(
        value: match,
        groupValue: c.match,
        text: Text(_matchLabel(l, match)),
        onChanged: (m) => onChange(c.copyWith(match: m)),
      );
    }

    return [
      MenuFlyoutSubItem(
        text: Text(l.rulerSettingsMenu_unit),
        items: (_) => [
          unitItem(RulerUnit.cm, l.rulerSettingsMenu_unitCm),
          unitItem(RulerUnit.inch, l.rulerSettingsMenu_unitInch),
        ],
      ),
      const MenuFlyoutSeparator(),
      MenuFlyoutSubItem(
        text: Text(l.rulerSettingsMenu_matchSquares),
        items: (_) => [for (final m in rulerMatchesFor(c.unit)) matchItem(m)],
      ),
    ];
  }

  String _matchLabel(AppLocalizations l, RulerGridMatch match) => switch (match) {
        RulerGridMatch.none => l.rulerSettingsMenu_matchNone,
        RulerGridMatch.cmPerSquare => l.rulerSettingsMenu_matchCmPerSquare,
        RulerGridMatch.quarterInchPerSquare => l.rulerSettingsMenu_matchQuarterInch,
        RulerGridMatch.fifthInchPerSquare => l.rulerSettingsMenu_matchFifthInch,
      };

}
