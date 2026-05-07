import 'package:flutter/painting.dart';

extension CanvasExtension on Canvas {

  /// Adapted from: https://gist.github.com/tarakparab/8aacf3c46922bc832f786fa811ee9b08
  void drawRotatedText({
    required Offset pivot,
    required TextPainter textPainter,
    required double radians,
    Alignment alignment = Alignment.center,
  }) {
    textPainter.layout();

    // Calculate delta. Delta is the top left offset with reference
    // to which the main text will paint. The centre of the text will be
    // at the given pivot unless [alignment] is set.
    final w = textPainter.width;
    final h = textPainter.height;
    final delta = pivot.translate(-w / 2 + w / 2 * alignment.x, -h / 2 + h / 2 * alignment.y);

    // Rotate the text about pivot.
    save();
    translate(pivot.dx, pivot.dy);
    rotate(radians);
    translate(-pivot.dx, -pivot.dy);
    textPainter.paint(this, delta);
    restore();
  }

}
