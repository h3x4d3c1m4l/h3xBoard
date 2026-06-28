import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ---------------------------------------------------------------------------
// Shared stateful shell
// ---------------------------------------------------------------------------

class _AnalogClockWidget extends StatefulWidget {

  static const Size naturalSize = Size(300, 300);

  final AnalogClockStyle style;
  final bool showSeconds;

  const _AnalogClockWidget({required this.style, this.showSeconds = true});

  @override
  State<_AnalogClockWidget> createState() => _AnalogClockWidgetState();

}

class _AnalogClockWidgetState extends State<_AnalogClockWidget> {

  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: _AnalogClockWidget.naturalSize,
      painter: switch (widget.style) {
        AnalogClockStyle.trainStation => _TrainStationPainter(_now, widget.showSeconds),
        AnalogClockStyle.classic      => _ClassicPainter(_now, widget.showSeconds),
        AnalogClockStyle.roman        => _RomanPainter(_now, widget.showSeconds),
      },
    );
  }

}

// ---------------------------------------------------------------------------
// Shared angle helpers
// ---------------------------------------------------------------------------

double _hourAngle(DateTime t) => (t.hour % 12 + t.minute / 60.0) * 30.0;
double _minuteAngle(DateTime t) => (t.minute + t.second / 60.0) * 6.0;
double _secondAngle(DateTime t) => t.second * 6.0;

// ---------------------------------------------------------------------------
// Train station clock (Mondaine / SBB style)
// ---------------------------------------------------------------------------

class _TrainStationPainter extends CustomPainter {

  final DateTime time;
  final bool showSeconds;

  const _TrainStationPainter(this.time, this.showSeconds);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas
      ..drawCircle(center, radius, Paint()..color = const Color(0xFFFFFFFF))
      ..drawCircle(
        center,
        radius - 1,
        Paint()
          ..color = const Color(0xFF1A1A1A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final angle = i * 6.0 * math.pi / 180;
      final isHour = i % 5 == 0;
      final outer = radius - 4;
      final inner = isHour ? outer - 18 : outer - 8;
      tickPaint
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = isHour ? 5 : 2;
      final cos = math.cos(angle - math.pi / 2);
      final sin = math.sin(angle - math.pi / 2);
      canvas.drawLine(
        Offset(center.dx + cos * inner, center.dy + sin * inner),
        Offset(center.dx + cos * outer, center.dy + sin * outer),
        tickPaint,
      );
    }

    _drawHand(canvas, center, _hourAngle(time), radius * 0.52, 9, const Color(0xFF1A1A1A));
    _drawHand(canvas, center, _minuteAngle(time), radius * 0.72, 7, const Color(0xFF1A1A1A));

    if (showSeconds) {
      final secAngle = (_secondAngle(time) - 90) * math.pi / 180;
      final secPaint = Paint()
        ..color = const Color(0xFFE30613)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final tipEnd = Offset(
        center.dx + math.cos(secAngle) * radius * 0.78,
        center.dy + math.sin(secAngle) * radius * 0.78,
      );
      final tailEnd = Offset(
        center.dx - math.cos(secAngle) * radius * 0.22,
        center.dy - math.sin(secAngle) * radius * 0.22,
      );
      canvas
        ..drawLine(tailEnd, tipEnd, secPaint)
        ..drawCircle(tipEnd, 5, Paint()..color = const Color(0xFFE30613))
        ..drawCircle(center, 5, Paint()..color = const Color(0xFFE30613));
    } else {
      canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF1A1A1A));
    }
  }

  void _drawHand(Canvas canvas, Offset center, double angleDeg, double length, double width, Color color) {
    final angle = (angleDeg - 90) * math.pi / 180;
    final tip = Offset(center.dx + math.cos(angle) * length, center.dy + math.sin(angle) * length);
    final tail = Offset(center.dx - math.cos(angle) * length * 0.18, center.dy - math.sin(angle) * length * 0.18);
    canvas.drawLine(tail, tip, Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_TrainStationPainter old) => old.time != time || old.showSeconds != showSeconds;

}

// ---------------------------------------------------------------------------
// Classic clock (dark navy, gold accents)
// ---------------------------------------------------------------------------

class _ClassicPainter extends CustomPainter {

  final DateTime time;
  final bool showSeconds;

  const _ClassicPainter(this.time, this.showSeconds);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas
      ..drawCircle(center, radius, Paint()..color = const Color(0xFF0B1B3E))
      ..drawCircle(
        center,
        radius - 6,
        Paint()
          ..color = const Color(0xFFD4AF37)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      )
      ..drawCircle(center, radius - 10, Paint()..color = const Color(0xFF0F2454))
      ..drawCircle(
        center,
        radius - 11,
        Paint()
          ..color = const Color(0xFFD4AF37).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

    final goldPaint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final angle = i * 6.0 * math.pi / 180;
      final isHour = i % 5 == 0;
      final outer = radius - 14;
      final inner = isHour ? outer - 14 : outer - 6;
      goldPaint
        ..color = const Color(0xFFD4AF37)
        ..strokeWidth = isHour ? 3 : 1.2;
      final cos = math.cos(angle - math.pi / 2);
      final sin = math.sin(angle - math.pi / 2);
      canvas.drawLine(
        Offset(center.dx + cos * inner, center.dy + sin * inner),
        Offset(center.dx + cos * outer, center.dy + sin * outer),
        goldPaint,
      );
    }

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 1; i <= 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final textRadius = radius - 46;
      final pos = Offset(
        center.dx + math.cos(angle) * textRadius,
        center.dy + math.sin(angle) * textRadius,
      );
      tp
        ..text = TextSpan(
          text: '$i',
          style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.w600),
        )
        ..layout()
        ..paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    _drawHand(canvas, center, _hourAngle(time), radius * 0.48, 7, const Color(0xFFEDE0B0));
    _drawHand(canvas, center, _minuteAngle(time), radius * 0.68, 5, const Color(0xFFEDE0B0));

    if (showSeconds) {
      final secAngle = (_secondAngle(time) - 90) * math.pi / 180;
      final secPaint = Paint()
        ..color = const Color(0xFFD4AF37)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final tip = Offset(
        center.dx + math.cos(secAngle) * radius * 0.74,
        center.dy + math.sin(secAngle) * radius * 0.74,
      );
      final tail = Offset(
        center.dx - math.cos(secAngle) * radius * 0.18,
        center.dy - math.sin(secAngle) * radius * 0.18,
      );
      canvas
        ..drawLine(tail, tip, secPaint)
        ..drawCircle(center, 4, Paint()..color = const Color(0xFFD4AF37));
    } else {
      canvas.drawCircle(center, 4, Paint()..color = const Color(0xFFD4AF37));
    }

    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFF0F2454));
  }

  void _drawHand(Canvas canvas, Offset center, double angleDeg, double length, double width, Color color) {
    final angle = (angleDeg - 90) * math.pi / 180;
    final tip = Offset(center.dx + math.cos(angle) * length, center.dy + math.sin(angle) * length);
    final tail = Offset(center.dx - math.cos(angle) * length * 0.15, center.dy - math.sin(angle) * length * 0.15);
    canvas.drawLine(tail, tip, Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_ClassicPainter old) => old.time != time || old.showSeconds != showSeconds;

}

// ---------------------------------------------------------------------------
// Roman numeral clock (warm parchment / antique style)
// ---------------------------------------------------------------------------

const _romanNumerals = ['XII', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI'];

class _RomanPainter extends CustomPainter {

  final DateTime time;
  final bool showSeconds;

  const _RomanPainter(this.time, this.showSeconds);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas
      ..drawCircle(center, radius, Paint()..color = const Color(0xFFF5EDD6))
      ..drawCircle(
        center,
        radius - 2,
        Paint()
          ..color = const Color(0xFF6B4226)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      )
      ..drawCircle(
        center,
        radius - 8,
        Paint()
          ..color = const Color(0xFF9B6B3A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

    // Numerals sit near the edge; ticks live on a separate inner ring
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final pos = Offset(
        center.dx + math.cos(angle) * (radius - 22),
        center.dy + math.sin(angle) * (radius - 22),
      );
      tp
        ..text = TextSpan(
          text: _romanNumerals[i],
          style: const TextStyle(
            color: Color(0xFF3D1F0A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        )
        ..layout()
        ..paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // Tick ring sits well inside the numeral ring
    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    final tickOuter = radius - 52;
    for (var i = 0; i < 60; i++) {
      final angle = i * 6.0 * math.pi / 180;
      final isHour = i % 5 == 0;
      final tickInner = isHour ? tickOuter - 12 : tickOuter - 6;
      tickPaint
        ..color = const Color(0xFF6B4226)
        ..strokeWidth = isHour ? 3 : 1.2;
      final cos = math.cos(angle - math.pi / 2);
      final sin = math.sin(angle - math.pi / 2);
      canvas.drawLine(
        Offset(center.dx + cos * tickInner, center.dy + sin * tickInner),
        Offset(center.dx + cos * tickOuter, center.dy + sin * tickOuter),
        tickPaint,
      );
    }

    _drawHand(canvas, center, _hourAngle(time), radius * 0.48, 7, const Color(0xFF3D1F0A));
    _drawHand(canvas, center, _minuteAngle(time), radius * 0.68, 5, const Color(0xFF3D1F0A));

    if (showSeconds) {
      final secAngle = (_secondAngle(time) - 90) * math.pi / 180;
      final secPaint = Paint()
        ..color = const Color(0xFF9B2020)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final tip = Offset(
        center.dx + math.cos(secAngle) * radius * 0.74,
        center.dy + math.sin(secAngle) * radius * 0.74,
      );
      final tail = Offset(
        center.dx - math.cos(secAngle) * radius * 0.2,
        center.dy - math.sin(secAngle) * radius * 0.2,
      );
      canvas
        ..drawLine(tail, tip, secPaint)
        ..drawCircle(center, 4, Paint()..color = const Color(0xFF9B2020));
    } else {
      canvas.drawCircle(center, 4, Paint()..color = const Color(0xFF3D1F0A));
    }

    canvas.drawCircle(center, 2.5, Paint()..color = const Color(0xFFF5EDD6));
  }

  void _drawHand(Canvas canvas, Offset center, double angleDeg, double length, double width, Color color) {
    final angle = (angleDeg - 90) * math.pi / 180;
    final tip = Offset(center.dx + math.cos(angle) * length, center.dy + math.sin(angle) * length);
    final tail = Offset(center.dx - math.cos(angle) * length * 0.15, center.dy - math.sin(angle) * length * 0.15);
    canvas.drawLine(tail, tip, Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RomanPainter old) => old.time != time || old.showSeconds != showSeconds;

}

// ---------------------------------------------------------------------------
// Descriptor
// ---------------------------------------------------------------------------

class AnalogClockWidgetDescriptor extends BoardWidgetDescriptor {

  static const AnalogClockWidgetDescriptor instance = AnalogClockWidgetDescriptor._();
  const AnalogClockWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.clock3;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_analogClock;

  @override
  Size naturalSize(BoardWidgetConfig config) => _AnalogClockWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const AnalogClockConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as AnalogClockConfig;
    return _AnalogClockWidget(style: c.style, showSeconds: c.showSeconds);
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as AnalogClockConfig;
    final l = context.localizations;

    RadioMenuFlyoutItem<AnalogClockStyle> styleItem(AnalogClockStyle style, String label) {
      return RadioMenuFlyoutItem<AnalogClockStyle>(
        value: style,
        groupValue: c.style,
        text: Text(label),
        onChanged: (s) => onChange(c.copyWith(style: s)),
      );
    }

    return [
      MenuFlyoutSubItem(
        text: Text(l.analogClockSettingsMenu_style),
        items: (_) => [
          styleItem(AnalogClockStyle.trainStation, l.analogClockSettingsMenu_styleTrainStation),
          styleItem(AnalogClockStyle.classic,      l.analogClockSettingsMenu_styleClassic),
          styleItem(AnalogClockStyle.roman,        l.analogClockSettingsMenu_styleRoman),
        ],
      ),
      const MenuFlyoutSeparator(),
      ToggleMenuFlyoutItem(
        value: c.showSeconds,
        text: Text(l.clockSettingsMenu_showSeconds),
        onChanged: (value) => onChange(c.copyWith(showSeconds: value)),
      ),
    ];
  }

}
