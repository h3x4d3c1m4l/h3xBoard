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

/// A subtle, slowly-drifting tiled background of pencil and eraser icons,
/// fitting h3xBoard's drawing-board theme. It scrolls diagonally and loops
/// seamlessly, reading as a faint watermark behind whatever it sits under.
///
/// Used both behind dialog content (where the caller passes an explicit white
/// [color], since the dialog surface is accent-tinted) and as a full-page
/// backdrop on loading screens (where the default faint accent tint applies).
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

  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  Widget build(BuildContext context) {

    // Keep the loop duration responsive to a hot-reloaded _kPatternLoopSeconds
    // (the controller is created once, so set/refresh its duration here).
    final ms = (_kPatternLoopSeconds * 1000).round();
    if (_controller.duration?.inMilliseconds != ms) {
      _controller
        ..stop()
        ..duration = Duration(milliseconds: ms)
        ..repeat();
    }

    final color = widget.color ?? FluentTheme.of(context).accentColor.darkest.withValues(alpha: _kSubtlePatternOpacity);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _IconPatternPainter(progress: _controller.value, color: color),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

}

/// Paints a checkerboard of pencil/eraser glyphs, drifting by [progress] (0..1)
/// in the `(_kPatternDriftX, _kPatternDriftY)` direction. The icons alternate on
/// `(row + col)` parity, so the field only maps onto itself after an even-sum
/// cell shift; [_loopCells] advances a whole such period per loop so the wrap is
/// seamless for *any* drift (odd-sum drifts advance two cells instead of one).
class _IconPatternPainter extends CustomPainter {

  _IconPatternPainter({required this.progress, required this.color});

  final double progress;

  final Color color;

  static const List<IconData> _icons = [LucideIcons.pencil, LucideIcons.eraser];

  /// Cells advanced per loop: 1 when the drift sum is even, else 2 (so the
  /// checkerboard parity lines up again at the wrap and nothing visibly swaps).
  static const int _loopCells = (_kPatternDriftX + _kPatternDriftY) % 2 == 0 ? 1 : 2;

  @override
  void paint(Canvas canvas, Size size) {
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

    // Tilt the whole lattice by rotating the canvas around its center.
    canvas.save();
    final center = Offset(size.width / 2, size.height / 2);
    canvas
      ..translate(center.dx, center.dy)
      ..rotate(_kPatternTiltDegrees * math.pi / 180)
      ..translate(-center.dx, -center.dy);

    // The rotated grid must still cover the whole canvas, so iterate over the
    // bounding box of the screen rect expressed in the (rotated) grid frame.
    // Half-extents of that box grow with the tilt; +1 cell of slack covers the
    // drift wrap and partial edge cells.
    final cos = math.cos(_kPatternTiltDegrees * math.pi / 180).abs();
    final sin = math.sin(_kPatternTiltDegrees * math.pi / 180).abs();
    final halfW = (size.width * cos + size.height * sin) / 2;
    final halfH = (size.width * sin + size.height * cos) / 2;

    final startCol = ((center.dx - halfW - shiftX) / _kPatternCellSize).floor() - 1;
    final endCol = ((center.dx + halfW - shiftX) / _kPatternCellSize).ceil() + 1;
    final startRow = ((center.dy - halfH - shiftY) / _kPatternCellSize).floor() - 1;
    final endRow = ((center.dy + halfH - shiftY) / _kPatternCellSize).ceil() + 1;

    for (var row = startRow; row <= endRow; row++) {
      for (var col = startCol; col <= endCol; col++) {
        final painter = painters[(row + col) & 1];
        final cellX = col * _kPatternCellSize + shiftX;
        final cellY = row * _kPatternCellSize + shiftY;
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
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }

}
