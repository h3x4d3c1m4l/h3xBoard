import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/dice_roll.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

final math.Random _random = math.Random();

/// The config a roll produces.
///
/// The face is drawn here, on the presenter, and travels as config — a mirror is
/// handed a no-op onConfigChanged and so can never originate one. Only the
/// *tumble* is reproduced on each screen, from [DiceConfig.rollSeed].
DiceConfig rollDice(DiceConfig config, {math.Random? random, int? nowMs}) => config.copyWith(
      face: drawFace(random ?? _random),
      rollSeed: nextRollSeed(config.rollSeed),
      rolledAtEpochMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );

// Half the drawn die at rest, leaving a small margin inside [naturalSize].
const double _halfBox = 90;

// How far each face is pulled in from the silhouette, as a fraction of its own
// half-width. Reads as the bevel a real die has.
const double _faceInset = 0.035;

class DiceWidget extends StatefulWidget {

  static const Size naturalSize = Size(200, 200);

  final int face;
  final int rollSeed;
  final int? rolledAtEpochMs;
  final DiceStyle style;
  // Called when the die is tapped. Null disables rolling — which is what the
  // read-only mirror passes, so a viewer's tap does nothing while the tumble it
  // is already showing carries on.
  final VoidCallback? onRoll;

  const DiceWidget({
    super.key,
    this.face = 1,
    this.rollSeed = 0,
    this.rolledAtEpochMs,
    this.style = DiceStyle.ivory,
    this.onRoll,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();

}

class _DiceWidgetState extends State<DiceWidget> with SingleTickerProviderStateMixin {

  // A frame pump and nothing else. The roll's state is the config anchor, so the
  // Ticker's own elapsed Duration is deliberately ignored — it starts when *this*
  // screen mounted, and every mirror mounted at a different moment.
  //
  // An AnimationController would be the wrong primitive here for that reason: it
  // carries its own clock, which would have to be re-synced against the anchor on
  // every rebuild and would drift between syncs. A mirror joining halfway through
  // a roll has to pick the tumble up halfway through.
  late final Ticker _ticker = createTicker(_onFrame);

  // Milliseconds into the roll. A ValueNotifier rather than setState so a frame
  // costs a repaint of the die instead of a rebuild of the subtree.
  late final ValueNotifier<int> _elapsed = ValueNotifier(_read());

  int _read() => diceElapsedMs(widget.rolledAtEpochMs, DateTime.now().millisecondsSinceEpoch);

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a new anchor is a new roll. Changing the style mid-roll doesn't touch
    // the animation at all: none of it lives in the ticker, so re-reading the
    // anchor puts the tumble back exactly where it was, with no restart or snap.
    if (oldWidget.rolledAtEpochMs != widget.rolledAtEpochMs) _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  // Idempotent on purpose: Ticker.start() asserts when it is already active, and
  // this is reachable both from initState and from a re-roll that arrives while a
  // previous one is still in the air.
  void _syncTicker() {
    final elapsed = _read();
    _elapsed.value = elapsed;
    final rolling = elapsed < kDiceRollDurationMs;
    if (rolling && !_ticker.isActive) {
      _ticker.start();
    } else if (!rolling && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onFrame(Duration _) {
    final elapsed = _read();
    _elapsed.value = elapsed;
    if (elapsed >= kDiceRollDurationMs) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(widget.style);

    // The board keeps all widget bodies and the drawing canvas inside a single
    // RepaintBoundary, so without one of its own a rolling die would dirty the
    // whole 1920x1080 board raster on every frame for the length of the roll.
    final die = RepaintBoundary(
      child: CustomPaint(
        size: DiceWidget.naturalSize,
        painter: _DicePainter(
          elapsed: _elapsed,
          face: widget.face,
          rollSeed: widget.rollSeed,
          faceColor: palette.face,
          pipColor: palette.pip,
        ),
      ),
    );

    final sized = SizedBox(
      width: DiceWidget.naturalSize.width,
      height: DiceWidget.naturalSize.height,
      child: die,
    );

    if (widget.onRoll == null) return sized;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onRoll,
        child: sized,
      ),
    );
  }

}

({Color face, Color pip}) _paletteOf(DiceStyle style) => switch (style) {
      DiceStyle.ivory => (face: const Color(0xFFF8FAFC), pip: const Color(0xFF1E293B)),
      DiceStyle.red => (face: const Color(0xFFDC2626), pip: const Color(0xFFFFF1F2)),
      DiceStyle.blue => (face: const Color(0xFF2563EB), pip: const Color(0xFFEFF6FF)),
      DiceStyle.slate => (face: const Color(0xFF1E293B), pip: const Color(0xFFF8FAFC)),
    };

Color _tone(Color base, double intensity) => Color.from(
      alpha: base.a,
      red: base.r * intensity,
      green: base.g * intensity,
      blue: base.b * intensity,
    );

class _DicePainter extends CustomPainter {

  final ValueListenable<int> elapsed;
  final int face;
  final int rollSeed;
  final Color faceColor;
  final Color pipColor;

  _DicePainter({
    required this.elapsed,
    required this.face,
    required this.rollSeed,
    required this.faceColor,
    required this.pipColor,
  }) : super(repaint: elapsed);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    final rotation = diceOrientation(face, rollSeed, elapsed.value);
    final scale = fitScale(projectedCube(rotation), _halfBox);

    // The visible faces tile the silhouette exactly, so filling their union first
    // both hides the antialiasing hairline along every shared edge and becomes the
    // die's body where each face is inset over it.
    final body = Path();
    final visible = <int>[];
    for (var i = 0; i < 6; i++) {
      if (!isFrontFacing(rotation.apply(kFaceNormals[i]))) continue;
      visible.add(i);
      body.addPolygon(faceQuad(i, rotation, scale).map((q) => origin + q).toList(), true);
    }
    canvas.drawPath(body, Paint()..color = _tone(faceColor, 0.58));

    final fill = Paint();
    for (final i in visible) {
      final normal = rotation.apply(kFaceNormals[i]);
      final intensity = shadeOf(normal);
      final quad = faceQuad(i, rotation, scale, inset: _faceInset).map((q) => origin + q).toList();

      canvas.drawPath(_roundedPolygon(quad, scale * 0.16), fill..color = _tone(faceColor, intensity));

      fill.color = _tone(pipColor, intensity);
      for (final pip in kPipLayouts[i]) {
        canvas.drawPath(
          Path()..addPolygon(pipPolygon(i, pip, rotation, scale).map((q) => origin + q).toList(), true),
          fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DicePainter oldDelegate) =>
      oldDelegate.face != face ||
      oldDelegate.rollSeed != rollSeed ||
      oldDelegate.faceColor != faceColor ||
      oldDelegate.pipColor != pipColor;

}

/// [points] with its corners cut by [radius], so a die reads as a die rather than
/// as a cube. Corners shorter than twice the radius round by as much as they can.
Path _roundedPolygon(List<Offset> points, double radius) {
  final path = Path();
  final count = points.length;
  for (var i = 0; i < count; i++) {
    final corner = points[i];
    final toPrevious = points[(i - 1 + count) % count] - corner;
    final toNext = points[(i + 1) % count] - corner;
    final previousLength = toPrevious.distance;
    final nextLength = toNext.distance;

    // A face seen almost edge-on collapses to a sliver; rounding it would divide
    // by zero, and there is nothing to see there anyway.
    if (previousLength < 0.01 || nextLength < 0.01) {
      i == 0 ? path.moveTo(corner.dx, corner.dy) : path.lineTo(corner.dx, corner.dy);
      continue;
    }

    final start = corner + toPrevious * (math.min(radius, previousLength / 2) / previousLength);
    final end = corner + toNext * (math.min(radius, nextLength / 2) / nextLength);
    i == 0 ? path.moveTo(start.dx, start.dy) : path.lineTo(start.dx, start.dy);
    path.quadraticBezierTo(corner.dx, corner.dy, end.dx, end.dy);
  }
  return path..close();
}

class DiceWidgetDescriptor extends BoardWidgetDescriptor {

  static const DiceWidgetDescriptor instance = DiceWidgetDescriptor._();
  const DiceWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.dices;

  @override
  String get emoji => '🎲';

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_dice;

  @override
  Size naturalSize(BoardWidgetConfig config) => DiceWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const DiceConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as DiceConfig;
    return DiceWidget(
      face: c.face,
      rollSeed: c.rollSeed,
      rolledAtEpochMs: c.rolledAtEpochMs,
      style: c.style,
      onRoll: () => onConfigChanged(rollDice(c)),
    );
  }

  // Deliberately no editAction: a descriptor that returns one makes the board wrap
  // the body in a double-tap recognizer, which holds the gesture arena for ~300ms
  // on every tap. On a die that turns each roll into a visible stall.

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as DiceConfig;
    final loc = context.localizations;

    RadioMenuFlyoutItem<DiceStyle> styleItem(DiceStyle style, String label) {
      return RadioMenuFlyoutItem<DiceStyle>(
        value: style,
        groupValue: c.style,
        text: Text(label),
        trailing: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _paletteOf(style).face,
            border: Border.all(color: const Color(0x44000000)),
          ),
        ),
        onChanged: (value) => onChange(c.copyWith(style: value)),
      );
    }

    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.dices, size: 16),
        text: Text(loc.diceSettingsMenu_roll),
        onPressed: () => onChange(rollDice(c)),
      ),
      const MenuFlyoutSeparator(),
      styleItem(DiceStyle.ivory, loc.diceSettingsMenu_styleIvory),
      styleItem(DiceStyle.red, loc.diceSettingsMenu_styleRed),
      styleItem(DiceStyle.blue, loc.diceSettingsMenu_styleBlue),
      styleItem(DiceStyle.slate, loc.diceSettingsMenu_styleSlate),
    ];
  }

}
