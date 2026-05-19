import 'package:freezed_annotation/freezed_annotation.dart';

part 'board_widget.freezed.dart';

enum TrafficLightColor { red, yellow, green }

@freezed
sealed class BoardWidgetConfig with _$BoardWidgetConfig {

  const factory BoardWidgetConfig.clock({
    @Default(true) bool use24h,
    @Default(true) bool showSeconds,
  }) = ClockConfig;

  const factory BoardWidgetConfig.trafficLight({
    @Default(TrafficLightColor.red) TrafficLightColor activeLight,
  }) = TrafficLightConfig;

  const factory BoardWidgetConfig.stopwatch({
    @Default(true) bool showCentiseconds,
  }) = StopwatchConfig;

}

@freezed
abstract class BoardWidget with _$BoardWidget {

  const BoardWidget._();

  const factory BoardWidget({
    required String id,
    required BoardWidgetConfig config,
    required double x,
    required double y,
    @Default(0.0) double rotation,
    @Default(1.0) double scale,
  }) = _BoardWidget;

}
