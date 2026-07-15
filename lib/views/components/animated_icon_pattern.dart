import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ── Tuning knobs for the animated background pattern ───────────────────────
/// Seconds for one full seamless loop — the grid advances by
/// [_kPatternDriftX]/[_kPatternDriftY] cells over this time. Lower = faster.
const double _kPatternLoopSeconds = 16;

/// Opacity of the glyphs when the pattern is used as a page background (behind a
/// loading screen). Deliberately faint: it should read as texture, never content.
///
/// The tint is the *darkest* accent shade, not the accent itself — the app accent
/// is a neon green whose luminance is nearly that of the gray page background, so
/// a low-alpha wash of it would be invisible. The dark shade keeps the green hue
/// while actually reading against the background.
const double _kSubtlePatternOpacity = 0.12;

/// Size (px) of each tiled icon glyph. Smaller = daintier icons.
const double _kPatternIconSize = 18;

/// Grid cell size (px) — the spacing between icons. Smaller = denser, more icons.
const double _kPatternCellSize = 40;

/// Drift direction in grid cells per loop, per axis. Use any ints — the loop
/// stays seamless for any combination. `(1, 0)` = rightwards, `(1, 1)` =
/// down-right, `(1, -1)` = up-right, larger magnitudes = faster, `(0, 0)` =
/// static.
const int _kPatternDriftX = 1;

const int _kPatternDriftY = 0;

/// Tilt (degrees) of the whole icon lattice. `0` = axis-aligned grid; e.g. `20`
/// rotates the entire pattern (the drift direction rotates with it).
const double _kPatternTiltDegrees = -20;

/// Establishes a shared clock and coordinate frame for every [AnimatedIconPattern]
/// beneath it, so stacked patterns (e.g. a loading card sitting over a full-page
/// backdrop) drift in unison *and* line their grids up — the card's lattice
/// continues the page's exactly, instead of the two reading as disjoint layers.
///
/// Wrap the subtree that holds both patterns. A pattern with no scope ancestor
/// (an ordinary modal dialog floating over an arbitrary screen) just animates on
/// its own clock, centered on itself — the original behavior.
class PatternSyncScope extends StatefulWidget {

  /// Creates a pattern-sync scope around [child].
  const PatternSyncScope({super.key, required this.child});

  /// The subtree whose [AnimatedIconPattern]s should share a clock and frame.
  final Widget child;

  @override
  State<PatternSyncScope> createState() => _PatternSyncScopeState();

}

class _PatternSyncScopeState extends State<PatternSyncScope> with SingleTickerProviderStateMixin {

  late final AnimationController _controller = AnimationController(vsync: this);

  /// Marks the render box that defines the shared coordinate origin (its
  /// top-left) and the full field size every pattern paints against.
  final GlobalKey _originKey = GlobalKey();

  @override
  Widget build(BuildContext context) {

    // The controller is created once, so (re)apply the loop duration here — also
    // keeps it responsive to a hot-reloaded _kPatternLoopSeconds.
    final ms = (_kPatternLoopSeconds * 1000).round();
    if (_controller.duration?.inMilliseconds != ms) {
      _controller
        ..stop()
        ..duration = Duration(milliseconds: ms)
        ..repeat();
    }

    return _PatternSyncData(
      controller: _controller,
      originKey: _originKey,
      child: SizedBox.expand(key: _originKey, child: widget.child),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

}

/// Carries the shared [controller] and origin [originKey] down to descendant
/// [AnimatedIconPattern]s.
class _PatternSyncData extends InheritedWidget {

  const _PatternSyncData({
    required this.controller,
    required this.originKey,
    required super.child,
  });

  final AnimationController controller;

  final GlobalKey originKey;

  static _PatternSyncData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PatternSyncData>();

  @override
  bool updateShouldNotify(_PatternSyncData oldWidget) =>
      controller != oldWidget.controller || originKey != oldWidget.originKey;

}

/// A subtle, slowly-drifting tiled background of pencil and eraser icons,
/// fitting h3xBoard's drawing-board theme. It scrolls diagonally and loops
/// seamlessly, reading as a faint watermark behind whatever it sits under.
///
/// Used both behind dialog content (where the caller passes an explicit white
/// [color], since the dialog surface is accent-tinted) and as a full-page
/// backdrop on loading screens (where the default faint accent tint applies).
///
/// Under a [PatternSyncScope] it shares that scope's clock and coordinate frame,
/// so it lines up seamlessly with the other patterns in the scope; without one it
/// animates on its own clock, centered on itself.
class AnimatedIconPattern extends StatefulWidget {

  /// Creates an animated icon pattern.
  const AnimatedIconPattern({super.key, this.color});

  /// The glyph color. Defaults to a very faint dark-accent tint, which is what a
  /// page background wants; pass an explicit color when painting over a colored
  /// surface (e.g. white over an accent-tinted dialog).
  final Color? color;

  @override
  State<AnimatedIconPattern> createState() => _AnimatedIconPatternState();

}

class _AnimatedIconPatternState extends State<AnimatedIconPattern> with SingleTickerProviderStateMixin {

  /// Only created (and ticked) when there is no [PatternSyncScope] to borrow a
  /// clock from; stays null under a scope.
  AnimationController? _ownController;

  /// Attached to this pattern's box so it can measure its own offset within the
  /// scope's origin box.
  final GlobalKey _boxKey = GlobalKey();

  /// Returns the controller to drive from: the scope's shared one when present,
  /// otherwise a lazily-created private one (kept ticking at the loop duration).
  AnimationController _resolveController(_PatternSyncData? sync) {
    if (sync != null) {
      _ownController?.stop();
      return sync.controller;
    }
    final controller = _ownController ??= AnimationController(vsync: this);
    final ms = (_kPatternLoopSeconds * 1000).round();
    if (controller.duration?.inMilliseconds != ms) {
      controller
        ..stop()
        ..duration = Duration(milliseconds: ms)
        ..repeat();
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) {

    final sync = _PatternSyncData.maybeOf(context);
    final controller = _resolveController(sync);
    final color = widget.color ?? FluentTheme.of(context).accentColor.darkest.withValues(alpha: _kSubtlePatternOpacity);

    return RepaintBoundary(
      key: _boxKey,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          // Under a scope, paint against the scope's full field and this box's
          // offset within it, so every pattern shares one lattice. Falls back to
          // self-relative (field = own size, offset = 0) before first layout and
          // when there is no scope.
          Size? fieldSize;
          var originOffset = Offset.zero;
          if (sync != null) {
            final originBox = sync.originKey.currentContext?.findRenderObject() as RenderBox?;
            final selfBox = _boxKey.currentContext?.findRenderObject() as RenderBox?;
            if (originBox != null && selfBox != null && originBox.hasSize && selfBox.hasSize) {
              fieldSize = originBox.size;
              originOffset = selfBox.localToGlobal(Offset.zero, ancestor: originBox);
            }
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _IconPatternPainter(
              progress: controller.value,
              color: color,
              fieldSize: fieldSize,
              originOffset: originOffset,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

}

/// Paints a checkerboard of pencil/eraser glyphs, drifting by [progress] (0..1)
/// in the `(_kPatternDriftX, _kPatternDriftY)` direction. The icons alternate on
/// `(row + col)` parity, so the field only maps onto itself after an even-sum
/// cell shift; [_loopCells] advances a whole such period per loop so the wrap is
/// seamless for *any* drift (odd-sum drifts advance two cells instead of one).
///
/// [fieldSize] and [originOffset] let several painters share one lattice: each
/// paints the *whole* field (of size [fieldSize]) but shifted by its own
/// [originOffset] within it, so their grids and rotation centers coincide. Left
/// at their defaults (`fieldSize == size`, `originOffset == zero`) the painter is
/// self-contained — the grid is centered on and sized to its own canvas.
class _IconPatternPainter extends CustomPainter {

  _IconPatternPainter({
    required this.progress,
    required this.color,
    this.fieldSize,
    this.originOffset = Offset.zero,
  });

  final double progress;

  final Color color;

  final Size? fieldSize;

  final Offset originOffset;

  static const List<IconData> _icons = [LucideIcons.pencil, LucideIcons.eraser];

  /// Cells advanced per loop: 1 when the drift sum is even, else 2 (so the
  /// checkerboard parity lines up again at the wrap and nothing visibly swaps).
  static const int _loopCells = (_kPatternDriftX + _kPatternDriftY) % 2 == 0 ? 1 : 2;

  @override
  void paint(Canvas canvas, Size size) {
    // The lattice is laid out in the shared field's coordinates; this canvas is
    // just a window onto it, offset by originOffset (field point p draws at
    // p - originOffset locally).
    final field = fieldSize ?? size;
    final ox = originOffset.dx;
    final oy = originOffset.dy;

    final shiftX = progress * _kPatternCellSize * _kPatternDriftX * _loopCells;
    final shiftY = progress * _kPatternCellSize * _kPatternDriftY * _loopCells;

    // Lay out each glyph once, then paint it across every matching cell.
    final painters = _icons.map((icon) {
      return TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: _kPatternIconSize,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }).toList();

    // Tilt the whole lattice by rotating the canvas around the field's center
    // (expressed in this canvas's local coordinates), so every windowed painter
    // rotates about the same point.
    canvas.save();
    final center = Offset(field.width / 2 - ox, field.height / 2 - oy);
    canvas
      ..translate(center.dx, center.dy)
      ..rotate(_kPatternTiltDegrees * math.pi / 180)
      ..translate(-center.dx, -center.dy);

    // The rotated grid must still cover the whole field, so iterate over the
    // bounding box of the field rect expressed in the (rotated) grid frame.
    // Half-extents of that box grow with the tilt; +1 cell of slack covers the
    // drift wrap and partial edge cells. Bounds are in field (global) coords.
    final cos = math.cos(_kPatternTiltDegrees * math.pi / 180).abs();
    final sin = math.sin(_kPatternTiltDegrees * math.pi / 180).abs();
    final halfW = (field.width * cos + field.height * sin) / 2;
    final halfH = (field.width * sin + field.height * cos) / 2;
    final fcx = field.width / 2;
    final fcy = field.height / 2;

    final startCol = ((fcx - halfW - shiftX) / _kPatternCellSize).floor() - 1;
    final endCol = ((fcx + halfW - shiftX) / _kPatternCellSize).ceil() + 1;
    final startRow = ((fcy - halfH - shiftY) / _kPatternCellSize).floor() - 1;
    final endRow = ((fcy + halfH - shiftY) / _kPatternCellSize).ceil() + 1;

    for (var row = startRow; row <= endRow; row++) {
      for (var col = startCol; col <= endCol; col++) {
        final painter = painters[(row + col) & 1];
        // Cell position in field coords, translated into this canvas's frame.
        final cellX = col * _kPatternCellSize + shiftX - ox;
        final cellY = row * _kPatternCellSize + shiftY - oy;
        painter.paint(
          canvas,
          Offset(
            cellX + (_kPatternCellSize - painter.width) / 2,
            cellY + (_kPatternCellSize - painter.height) / 2,
          ),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPatternPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.fieldSize != fieldSize ||
        oldDelegate.originOffset != originOffset;
  }

}
