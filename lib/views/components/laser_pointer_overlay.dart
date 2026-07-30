import 'dart:collection';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:h3xboard/models/laser_pointer.dart';

/// Paints the virtual laser dot in the 1920×1080 canvas space, above
/// everything else on the board. Shared by the editor and by every mirror
/// (external display, web viewer) so the presenter's dot and the audience's
/// dot are the same drawing.
///
/// Place it inside the same fixed-size 1920×1080 box the board content uses;
/// it reads [pointer] straight in canvas coordinates and repaints on its own
/// whenever the value changes — the board around it never rebuilds.
///
/// Purely decorative and pointer-inert: it must sit *outside* the board's
/// screenshot [RepaintBoundary], or the dot would be baked into thumbnails.
class LaserPointerOverlay extends StatefulWidget {

  /// The dot's position and colour, or null when the laser is put away.
  final ValueListenable<LaserPointer?> pointer;

  const LaserPointerOverlay({super.key, required this.pointer});

  @override
  State<LaserPointerOverlay> createState() => _LaserPointerOverlayState();

}

class _LaserPointerOverlayState extends State<LaserPointerOverlay> {

  // Recent positions, oldest first, drawn as a fading comet tail behind the
  // dot. It costs nothing when the pointer is still (the samples pile up on
  // one spot and the tail collapses into the dot) and buys a lot when it
  // moves: on a projector or a web viewer the dot arrives in visible steps,
  // and a tail joining them reads as motion instead of as stutter.
  static const int _trailLength = 7;

  final Queue<Offset> _trail = Queue<Offset>();

  @override
  void initState() {
    super.initState();
    widget.pointer.addListener(_onPointerChanged);
    _seedTrail();
  }

  @override
  void didUpdateWidget(LaserPointerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pointer == oldWidget.pointer) return;
    oldWidget.pointer.removeListener(_onPointerChanged);
    widget.pointer.addListener(_onPointerChanged);
    _trail.clear();
    _seedTrail();
  }

  void _seedTrail() {
    final value = widget.pointer.value;
    if (value != null) _trail.add(Offset(value.x, value.y));
  }

  // Note this runs per *notification*, not per frame: when a batched transport
  // delivers several positions at once they all land in the trail even though
  // the painter only runs once afterwards. That is what keeps a mirror's tail
  // the same shape as the presenter's.
  void _onPointerChanged() {
    final value = widget.pointer.value;
    if (value == null) {
      _trail.clear();
      return;
    }
    _trail.addLast(Offset(value.x, value.y));
    while (_trail.length > _trailLength) {
      _trail.removeFirst();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _LaserPainter(pointer: widget.pointer, trail: _trail),
        size: const Size(1920, 1080),
      ),
    );
  }

  @override
  void dispose() {
    widget.pointer.removeListener(_onPointerChanged);
    super.dispose();
  }

}

/// The dot itself: a blurred bloom, a saturated ring, and a white-hot core.
///
/// The white core is the accessibility of this feature. Because it carries the
/// dot's luminance contrast, the hue underneath it is free to be any of
/// [LaserColor]'s four — including the ones that lose most of their perceived
/// brightness under red-green or blue-yellow colour vision deficiency, and
/// including red on a chalkboard, which is the case that fails in every other
/// product. It is also simply what a real laser dot looks like: a blown-out
/// centre in a coloured halo.
class _LaserPainter extends CustomPainter {

  // Canvas units (the board is a fixed 1920×1080), so the dot keeps its
  // proportions on every screen it is mirrored to.
  static const double _coreRadius = 7;
  static const double _ringRadius = 15;
  static const double _bloomRadius = 34;
  static const double _bloomBlur = 18;

  final ValueListenable<LaserPointer?> pointer;
  final Queue<Offset> trail;

  _LaserPainter({required this.pointer, required this.trail}) : super(repaint: pointer);

  @override
  void paint(Canvas canvas, Size size) {
    final value = pointer.value;
    if (value == null) return;
    final color = value.color.color;
    final center = Offset(value.x, value.y);

    _paintTrail(canvas, color);

    canvas
      ..drawCircle(
        center,
        _bloomRadius,
        Paint()
          ..color = color.withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _bloomBlur),
      )
      ..drawCircle(center, _ringRadius, Paint()..color = color.withValues(alpha: 0.85))
      // A hair of the hue is kept in the core so the dot still reads as
      // coloured rather than as a plain white blob.
      ..drawCircle(center, _coreRadius, Paint()..color = Color.lerp(Colors.white, color, 0.12)!);
  }

  /// Draws the tail as a tapering, fading stroke from the oldest sample to the
  /// newest. Skipped while the pointer is effectively still, where every
  /// sample sits on the dot and the tail would only add a smudge.
  void _paintTrail(Canvas canvas, Color color) {
    if (trail.length < 2) return;
    final points = trail.toList(growable: false);
    if ((points.last - points.first).distance < 2) return;

    for (var i = 0; i < points.length - 1; i++) {
      // 0 at the oldest sample, ~1 at the newest.
      final t = (i + 1) / (points.length - 1);
      canvas.drawLine(
        points[i],
        points[i + 1],
        Paint()
          ..color = color.withValues(alpha: 0.30 * t)
          ..strokeWidth = _ringRadius * 1.4 * t
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(_LaserPainter oldDelegate) => pointer != oldDelegate.pointer;

}
