import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

/// Serializes a [Color] as its 32-bit ARGB integer so boards round-trip
/// through the JSON `data` blob stored on the server.
class ColorConverter implements JsonConverter<Color, int> {

  const ColorConverter();

  @override
  Color fromJson(int json) => Color(json);

  @override
  int toJson(Color object) => object.toARGB32();

}
