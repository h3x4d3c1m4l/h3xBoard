import 'package:flutter_drawing_board/paint_contents.dart';

/// Rebuilds [PaintContent] instances from the JSON produced by
/// [DrawingController.getJsonList]. Shared by the editor
/// (board_screen_controller.dart) and the read-only external-display renderer,
/// so both understand exactly the same set of stroke types.
List<PaintContent> restoreDrawingContents(List<Map<String, dynamic>> jsonList) {
  return jsonList.map((json) {
    // The package's stroke `fromJson` hard-casts each numeric field to a fixed
    // type. A round-trip through the server drops the int/double distinction for
    // whole numbers (JSON stores both `1.0` and `1` as `1`), so a whole-pixel
    // coordinate comes back as an int and a `... as double` cast throws
    // "type 'int' is not a subtype of type 'double'". We can't just widen every
    // number to double, though: the same object mixes double fields (coordinates,
    // strokeWidth) with int fields (enum indices, packed color) that must stay
    // ints. So only the keys the package reads as double are coerced.
    final normalized = _normalizeMap(json);
    return switch (normalized['type'] as String?) {
      'SimpleLine' => SimpleLine.fromJson(normalized),
      'SmoothLine' => SmoothLine.fromJson(normalized),
      'StraightLine' => StraightLine.fromJson(normalized),
      'Rectangle' => Rectangle.fromJson(normalized),
      'Circle' => Circle.fromJson(normalized),
      'Eraser' => Eraser.fromJson(normalized),
      _ => null,
    };
  }).whereType<PaintContent>().toList();
}

/// JSON keys the drawing package reads with `... as double` — offsets, rect
/// bounds, radii, every path-step coordinate, the line configs, and the stroke
/// widths. A whole number under one of these keys must be coerced from int to
/// double; every other numeric key (enum indices, packed color) is left an int.
/// The two sets are disjoint across the package, so a per-key rule is
/// unambiguous. `strokeWidthList` holds bare doubles (not maps); passing its key
/// down through list recursion coerces each element.
const _doubleKeys = <String>{
  'dx', 'dy', 'x', 'y', 'w', 'left', 'top', 'right', 'bottom',
  'x1', 'y1', 'x2', 'y2', 'x3', 'y3',
  'radius', 'rotation', 'startAngle', 'sweepAngle',
  'strokeWidth', 'strokeWidthList', 'brushPrecision', 'minPointDistance',
};

/// Deep-copies [map] into a `Map<String, dynamic>`, coercing whole numbers to
/// doubles only under [_doubleKeys]. Two things must hold for the package's
/// stroke `fromJson` to accept the data: those fields must be doubles, and every
/// nested object must be typed `Map<String, dynamic>` (e.g. `SimpleLine` casts
/// each point with `as Map<String, dynamic>`). Decoded JSON already satisfies
/// the map typing, but rebuilding it widens the maps to `Map<dynamic, dynamic>`
/// unless we retype them here.
Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> map) {
  return <String, dynamic>{
    for (final entry in map.entries)
      entry.key as String: _normalizeValue(entry.key as String, entry.value),
  };
}

/// Recurses through [value], rebuilding maps via [_normalizeMap], preserving
/// list element types, and turning an int into a double only when its [key] is
/// a [_doubleKeys] member. Strings, bools, nulls and non-matching numbers pass
/// through untouched.
Object? _normalizeValue(String key, Object? value) {
  if (value is int && _doubleKeys.contains(key)) return value.toDouble();
  if (value is Map) return _normalizeMap(value);
  // Lists hold either nested maps (points, path steps) or bare doubles
  // (`strokeWidthList`). Recursing with the same [key] preserves the double
  // coercion for the bare-number case; for map elements the key is ignored.
  if (value is List) return <dynamic>[for (final item in value) _normalizeValue(key, item)];
  return value;
}
