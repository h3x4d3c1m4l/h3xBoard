import 'package:freezed_annotation/freezed_annotation.dart';

part 'board_widget.freezed.dart';

enum TrafficLightColor { red, yellow, green }

enum MemoNoteColor { yellow, green, blue, pink }

enum AnalogClockStyle { trainStation, classic, roman }

@freezed
sealed class BoardWidgetConfig with _$BoardWidgetConfig {

  const factory BoardWidgetConfig.digitalClock({
    @Default(true) bool use24h,
    @Default(true) bool showSeconds,
  }) = DigitalClockConfig;

  const factory BoardWidgetConfig.analogClock({
    @Default(AnalogClockStyle.classic) AnalogClockStyle style,
    @Default(true) bool showSeconds,
  }) = AnalogClockConfig;

  const factory BoardWidgetConfig.trafficLight({
    @Default(TrafficLightColor.red) TrafficLightColor activeLight,
  }) = TrafficLightConfig;

  const factory BoardWidgetConfig.stopwatch({
    @Default(true) bool showCentiseconds,
  }) = StopwatchConfig;

  const factory BoardWidgetConfig.memoNote({
    @Default('') String text,
    @Default(MemoNoteColor.yellow) MemoNoteColor color,
  }) = MemoNoteConfig;

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
    @Default(false) bool isVisibleOnAllBoards,
    @Default(<String>[]) List<String> visibleOnBoardIds,
  }) = _BoardWidget;

}
