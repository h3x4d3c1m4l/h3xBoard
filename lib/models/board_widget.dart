import 'package:freezed_annotation/freezed_annotation.dart';

part 'board_widget.freezed.dart';

enum BoardWidgetType { clock }

@freezed
abstract class BoardWidget with _$BoardWidget {
  const BoardWidget._();

  const factory BoardWidget({
    required String id,
    required BoardWidgetType type,
    required double x,
    required double y,
    @Default(0.0) double rotation,
    @Default(1.0) double scale,
  }) = _BoardWidget;
}
