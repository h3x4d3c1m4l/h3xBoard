import 'package:flutter_drawing_board/paint_contents.dart';

/// Rebuilds [PaintContent] instances from the JSON produced by
/// [DrawingController.getJsonList]. Shared by the editor
/// (board_screen_controller.dart) and the read-only external-display renderer,
/// so both understand exactly the same set of stroke types.
List<PaintContent> restoreDrawingContents(List<Map<String, dynamic>> jsonList) {
  return jsonList.map((json) {
    return switch (json['type'] as String?) {
      'SimpleLine' => SimpleLine.fromJson(json),
      'SmoothLine' => SmoothLine.fromJson(json),
      'StraightLine' => StraightLine.fromJson(json),
      'Rectangle' => Rectangle.fromJson(json),
      'Circle' => Circle.fromJson(json),
      'Eraser' => Eraser.fromJson(json),
      _ => null,
    };
  }).whereType<PaintContent>().toList();
}
