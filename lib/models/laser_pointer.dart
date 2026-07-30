import 'package:fluent_ui/fluent_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'laser_pointer.freezed.dart';
part 'laser_pointer.g.dart';

/// The colours the virtual laser pointer can be set to.
///
/// Red, green and blue are what a real presenter remote (and PowerPoint) offer,
/// so they are what people look for. [magenta] is the accessibility pick: it is
/// the one hue that keeps its luminance for protan, deutan *and* tritan viewers
/// and reads on both a white board and a chalkboard.
///
/// Hue is decoration here, not information — only ever one dot is on screen, so
/// nobody has to tell two colours apart. Visibility comes from the white-hot
/// core [LaserPointer] is painted with (see `LaserPointerOverlay`), which is why
/// even the weakest hue of the four stays legible for every kind of colour
/// vision.
enum LaserColor {

  red(Color(0xFFFF1A1A)),
  green(Color(0xFF15E52F)),
  blue(Color(0xFF2E7BFF)),
  magenta(Color(0xFFFF23C8));

  const LaserColor(this.color);

  /// The dot's hue. The rendered dot is this colour bloomed around a white
  /// core, not a flat fill of it.
  final Color color;

}

/// Where the presenter is pointing, in the canonical 1920×1080 canvas space
/// shared by the editor and every mirror.
///
/// Purely transient: it is never persisted with a board, never enters the
/// drawing history, and never appears in a thumbnail capture.
@freezed
abstract class LaserPointer with _$LaserPointer {

  const factory LaserPointer({
    required double x,
    required double y,
    // An unknown colour from a newer client falls back to red rather than
    // failing the frame — same tolerance the protocol's union has.
    @JsonKey(unknownEnumValue: LaserColor.red) required LaserColor color,
  }) = _LaserPointer;

  factory LaserPointer.fromJson(Map<String, dynamic> json) => _$LaserPointerFromJson(json);

}
