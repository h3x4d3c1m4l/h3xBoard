import 'package:fluent_ui/fluent_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:h3xboard/models/converters/color_converter.dart';
import 'package:h3xboard/models/programming_language.dart';

part 'board_widget.freezed.dart';
part 'board_widget.g.dart';

enum TrafficLightColor { red, yellow, green }

enum MemoNoteColor { yellow, green, blue, pink }

enum AnalogClockStyle { trainStation, classic, roman }

enum RulerUnit { cm, inch }

enum QrCodeStyle { smooth, square, dots }

// Off, or which "1 square = X" mapping the ruler is locked to. Only [cmPerSquare]
// is valid when the unit is cm; only the two inch mappings are valid for inch.
enum RulerGridMatch { none, cmPerSquare, quarterInchPerSquare, fifthInchPerSquare }

// Baseline canvas-units per cm at scale 1.0. The ruler painter draws its cm scale
// at this density; the geodreieck painter draws 1 cm = 10 units. Both feed the
// grid-match scale calcs below.
const double kRulerPxPerCm = 48;
const double kGeodreieckPxPerCm = 10;

// The scale a ruler must take so its units line up with the board grid squares
// ([lineSpacing] canvas units each), or null when it isn't matched. On-canvas cm
// spacing = kRulerPxPerCm * scale, so cmPerSquare needs kRulerPxPerCm * scale ==
// lineSpacing; the inch variants put 4 (resp. 5) squares per inch (1 inch = 2.54 cm).
double? rulerMatchScale(RulerConfig cfg, double lineSpacing) {
  switch (cfg.match) {
    case RulerGridMatch.none:
      return null;
    case RulerGridMatch.cmPerSquare:
      return lineSpacing / kRulerPxPerCm;
    case RulerGridMatch.quarterInchPerSquare:
      return 4 * lineSpacing / (2.54 * kRulerPxPerCm);
    case RulerGridMatch.fifthInchPerSquare:
      return 5 * lineSpacing / (2.54 * kRulerPxPerCm);
  }
}

// The match mappings selectable for a given unit (always including [none]).
List<RulerGridMatch> rulerMatchesFor(RulerUnit unit) => switch (unit) {
      RulerUnit.cm => const [RulerGridMatch.none, RulerGridMatch.cmPerSquare],
      RulerUnit.inch => const [
          RulerGridMatch.none,
          RulerGridMatch.quarterInchPerSquare,
          RulerGridMatch.fifthInchPerSquare,
        ],
    };

// The scale that aligns the geodreieck's cm marks to the grid squares, or null
// when it isn't matched.
double? geodreieckMatchScale(GeodreieckConfig cfg, double lineSpacing) =>
    cfg.matchSquares ? lineSpacing / kGeodreieckPxPerCm : null;

// Grid-match dispatch across widget types, so the view model and controller stay
// agnostic of which widgets support matching.
double? boardWidgetMatchScale(BoardWidgetConfig config, double lineSpacing) => switch (config) {
      RulerConfig c => rulerMatchScale(c, lineSpacing),
      GeodreieckConfig c => geodreieckMatchScale(c, lineSpacing),
      _ => null,
    };

bool boardWidgetIsGridMatched(BoardWidgetConfig config) => switch (config) {
      RulerConfig c => c.match != RulerGridMatch.none,
      GeodreieckConfig c => c.matchSquares,
      _ => false,
    };

/// Returns [config] with any stopwatch/timer running state reset to its default,
/// so two configs can be compared while ignoring their runtime anchor (see
/// [isWidgetRuntimeOnlyChange]).
BoardWidgetConfig clearWidgetRuntimeState(BoardWidgetConfig config) => switch (config) {
      StopwatchConfig c => c.copyWith(elapsedMs: 0, startedAtEpochMs: null),
      TimerConfig c => c.copyWith(elapsedMs: 0, startedAtEpochMs: null),
      // The playground is a scratchpad: typing code, filling in input and running
      // it are all working, not board edits. Collapsing every config to the
      // default makes any two compare equal here, so changes mirror to the second
      // screen and autosave without consuming undo — a class would otherwise bury
      // the teacher's drawing history under a lesson's worth of keystrokes.
      // Nothing is lost: the editor brings its own undo, which is the Ctrl+Z a
      // person typing code actually expects.
      CodePlaygroundConfig() => const CodePlaygroundConfig(),
      _ => config,
    };

/// Whether two configs differ only in ephemeral runtime state (the stopwatch/
/// timer running anchor). Such changes must reach the external mirror but stay
/// out of undo history and autosave.
bool isWidgetRuntimeOnlyChange(BoardWidgetConfig oldConfig, BoardWidgetConfig newConfig) =>
    oldConfig.runtimeType == newConfig.runtimeType &&
    oldConfig != newConfig &&
    clearWidgetRuntimeState(oldConfig) == clearWidgetRuntimeState(newConfig);

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
    // Live running state, saved with the board and mirrored to the external
    // display. Wall-clock anchor: while running [startedAtEpochMs] is set and
    // elapsed = [elapsedMs] + (now - started); while paused it is null and elapsed
    // = [elapsedMs]. Persisted so a running clock survives a crash/restart.
    @Default(0) int elapsedMs,
    int? startedAtEpochMs,
  }) = StopwatchConfig;

  const factory BoardWidgetConfig.timer({
    @Default(300) int durationSeconds,
    @Default(false) bool showCentiseconds,
    // Same wall-clock anchor as the stopwatch; remaining = duration - elapsed.
    @Default(0) int elapsedMs,
    int? startedAtEpochMs,
  }) = TimerConfig;

  const factory BoardWidgetConfig.memoNote({
    @Default('') String text,
    @Default(MemoNoteColor.yellow) MemoNoteColor color,
  }) = MemoNoteConfig;

  const factory BoardWidgetConfig.piano({
    @Default(1) int octaves,
  }) = PianoConfig;

  const factory BoardWidgetConfig.todoList({
    @Default('') String title,
    @Default(<TodoItem>[]) List<TodoItem> items,
  }) = TodoListConfig;

  const factory BoardWidgetConfig.ruler({
    @Default(RulerUnit.cm) RulerUnit unit,
    @Default(RulerGridMatch.none) RulerGridMatch match,
  }) = RulerConfig;

  const factory BoardWidgetConfig.geodreieck({
    @Default(false) bool matchSquares,
  }) = GeodreieckConfig;

  // [width]/[height] hold the picked image's intrinsic pixel size so the widget
  // frames at its real aspect ratio; null until an image is chosen.
  const factory BoardWidgetConfig.image({
    @Default('') String fileId,
    double? width,
    double? height,
  }) = ImageConfig;

  // A chrome-less text label. Unlike [MemoNoteConfig] (a fixed-size sticky note
  // rendering Markdown) this is bare highlighted text, sized to its content and
  // meant to be dragged around the board as a label.
  // [fontSize] is the size the label is laid out at, not a user setting: labels
  // are resized by dragging their corner handles, which scales the whole widget.
  // It stays in the model so labels saved before that decision keep their size.
  const factory BoardWidgetConfig.textBox({
    @Default('') String text,
    @ColorConverter() @Default(Color(0xFF1A1A1A)) Color backgroundColor,
    @ColorConverter() @Default(Color(0xFFFFFFFF)) Color textColor,
    @Default(64.0) double fontSize,
    @Default(TextAlign.left) TextAlign textAlign,
  }) = TextBoxConfig;

  const factory BoardWidgetConfig.qrCode({
    @Default('') String data,
    @Default(QrCodeStyle.smooth) QrCodeStyle style,
  }) = QrCodeConfig;

  /// A place to write a short program, run it, and show a class what came out.
  ///
  /// Everything the widget displays lives here — the code, the pre-filled input,
  /// and the output of the last run — so all of it mirrors to the external
  /// display and to web viewers, and survives a reload. The program itself runs
  /// only on the device being edited; a mirror shows the last result and never
  /// executes anything.
  ///
  /// [stdinText] is fed to `input()` line by line. Supplying it up front rather
  /// than prompting mid-run is partly a technical necessity — a blocking prompt
  /// would need SharedArrayBuffer, and so COOP/COEP headers on the whole app —
  /// and partly better teaching, since the class can see what is going in.
  ///
  /// [exitCode] is null until the program has been run at least once, which is
  /// what tells an empty output panel apart from a program that printed nothing.
  ///
  /// [caretLine] and [caretColumn] carry the presenter's cursor, so a mirror can
  /// show a class *where* the teacher is typing and not just what appears. Both
  /// are null whenever the presenter is not in the code editor — the mirror then
  /// draws no caret rather than a stale one.
  const factory BoardWidgetConfig.codePlayground({
    @Default(ProgrammingLanguage.python)
    @JsonKey(unknownEnumValue: ProgrammingLanguage.python)
    ProgrammingLanguage language,
    @Default('print("Hello, class!")\n') String code,
    @Default('') String stdinText,
    @Default('') String stdout,
    @Default('') String stderr,
    int? exitCode,
    @Default(false) bool outputTruncated,
    @Default(0) int durationMs,
    int? caretLine,
    int? caretColumn,
  }) = CodePlaygroundConfig;

  factory BoardWidgetConfig.fromJson(Map<String, dynamic> json) => _$BoardWidgetConfigFromJson(json);

}

@freezed
abstract class TodoItem with _$TodoItem {

  const factory TodoItem({
    required String text,
    @Default(false) bool done,
  }) = _TodoItem;

  factory TodoItem.fromJson(Map<String, dynamic> json) => _$TodoItemFromJson(json);

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

  // A ruler in a grid-match mode owns its scale (driven by the board grid), so
  // manual resize is disabled for it. Move and rotate stay available.
  bool get isScaleLocked {
    final c = config;
    return c is RulerConfig && c.match != RulerGridMatch.none;
  }

  factory BoardWidget.fromJson(Map<String, dynamic> json) => _$BoardWidgetFromJson(json);

}
