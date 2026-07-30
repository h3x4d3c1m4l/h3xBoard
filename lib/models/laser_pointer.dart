import 'package:fluent_ui/fluent_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'laser_pointer.freezed.dart';
part 'laser_pointer.g.dart';

enum LaserColor {

  red(Color(0xFFFF1A1A)),
  green(Color(0xFF15E52F)),
  blue(Color(0xFF2E7BFF)),
  magenta(Color(0xFFFF23C8));

  const LaserColor(this.color);

  final Color color;

}

@freezed
abstract class LaserPointer with _$LaserPointer {

  const factory LaserPointer({
    required double x,
    required double y,
    @JsonKey(unknownEnumValue: LaserColor.red) required LaserColor color,
  }) = _LaserPointer;

  factory LaserPointer.fromJson(Map<String, dynamic> json) => _$LaserPointerFromJson(json);

}
