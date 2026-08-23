import 'package:fluent_ui/fluent_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:h3xboard/models/converters/color_converter.dart';

part 'board_widget.freezed.dart';
part 'board_widget.g.dart';

enum TrafficLightColor { red, yellow, green }

enum MemoNoteColor { yellow, green, blue, pink }

enum AnalogClockStyle { trainStation, classic, roman }

enum RulerUnit { cm, inch }

enum QrCodeStyle { smooth, square, dots }

// The die's palette. An enum rather than two free colours so face and pips can
// never be set to the same thing.
enum DiceStyle { ivory, red, blue, slate }

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

/// Returns [config] with any stopwatch/timer running state, dice roll or sound-pad trigger reset to its default. Two
/// configs can then be compared while ignoring their runtime anchor (see [isWidgetRuntimeOnlyChange]).
BoardWidgetConfig clearWidgetRuntimeState(BoardWidgetConfig config) => switch (config) {
      StopwatchConfig c => c.copyWith(elapsedMs: 0, startedAtEpochMs: null),
      TimerConfig c => c.copyWith(elapsedMs: 0, startedAtEpochMs: null),
      SoundPadConfig c => c.copyWith(triggerSeed: 0, stopSeed: 0),
      AudioPlayerConfig c => c.copyWith(positionMs: 0, startedAtEpochMs: null),
      DiceConfig c => c.copyWith(face: 1, rollSeed: 0, rolledAtEpochMs: null),
      NumberDiceConfig c => c.copyWith(value: 0, rollSeed: 0, rolledAtEpochMs: null),
      _ => config,
    };

/// Whether two configs differ only in ephemeral runtime state (the stopwatch/
/// timer running anchor, or a dice roll). Such changes must reach the external
/// mirror and are persisted, but stay out of undo history.
bool isWidgetRuntimeOnlyChange(BoardWidgetConfig oldConfig, BoardWidgetConfig newConfig) =>
    oldConfig.runtimeType == newConfig.runtimeType &&
    oldConfig != newConfig &&
    clearWidgetRuntimeState(oldConfig) == clearWidgetRuntimeState(newConfig);

/// A caption from an uploaded file's name, with the extension dropped. A pad
/// reading "applause.mp3" says nothing "applause" doesn't.
///
/// Empty when the caller has no name to offer, which both widgets render as
/// their own placeholder.
String captionForFileName(String? fileName) {
  if (fileName == null || fileName.isEmpty) return '';
  final dot = fileName.lastIndexOf('.');
  return dot <= 0 ? fileName : fileName.substring(0, dot);
}

/// The uploaded file a widget takes its **caption** from, or null when it has
/// none.
///
/// Narrower than the set of files a board references. An image widget and a
/// board background have bytes but no caption, so renaming those changes
/// nothing on screen.
String? boardWidgetCaptionFileId(BoardWidgetConfig config) => switch (config) {
      SoundPadConfig(:final fileId) when fileId.isNotEmpty => fileId,
      AudioPlayerConfig(:final fileId) when fileId.isNotEmpty => fileId,
      _ => null,
    };

/// [config] with its caption re-derived from [fileName], or unchanged when it
/// carries no caption.
///
/// A caption is a snapshot of the file's name taken when it was picked, so it
/// goes stale as soon as the file is renamed. Boards re-derive it on load rather
/// than storing a live lookup. Mirrors never see file metadata: the external
/// display and web viewers receive bytes, so the name has to travel with the
/// config.
BoardWidgetConfig boardWidgetWithCaption(BoardWidgetConfig config, String fileName) => switch (config) {
      SoundPadConfig c => c.copyWith(label: captionForFileName(fileName)),
      AudioPlayerConfig c => c.copyWith(title: captionForFileName(fileName)),
      _ => config,
    };

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
    @Default(true) bool showProgressRing,
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

  const factory BoardWidgetConfig.emoji({
    @Default('😀') String emoji,
  }) = EmojiConfig;

  // A soundboard button: one uploaded sound, an emoji to recognise it by.
  //
  // Playback travels as config, like a dice roll — but *unlike* the dice and the stopwatch it carries no wall-clock
  // anchor, and that difference is deliberate. Those two reconstruct their state from `now - anchor`, which is fine
  // when being a few seconds off still looks like a stopwatch. A sound is unforgiving: if the presenter's clock and a
  // viewer's disagree by more than the clip is long, reconstructing from an anchor plays nothing at all.
  //
  // So [triggerSeed] is an edge, not a timestamp: it advances by one per tap. A receiver that sees [triggerSeed] change
  // plays from the start using its own clock. That is immune to skew by construction. The edge doubles as the answer to
  // re-tapping a pad that is already sounding — a new edge is a new voice, layered over the old one.
  //
  // [stopSeed] is the same trick for the stop badge, which silences every voice this pad has going. Two counters
  // rather than one field, because a single counter cannot say which of the two happened.
  //
  // [durationMs] is filled in when the sound is picked (see SoundPadWidgetDescriptor), not when it is played, so it is
  // part of the edit rather than runtime state.
  const factory BoardWidgetConfig.soundPad({
    @Default('') String fileId,
    @Default('') String label,
    @Default('🔊') String emoji,
    @Default(1.0) double volume,
    @Default(0) int triggerSeed,
    @Default(0) int stopSeed,
    int? durationMs,
  }) = SoundPadConfig;

  // A full transport for one uploaded track: play/pause, scrub, loop, volume.
  //
  // [startedAtEpochMs] is null while paused, and [positionMs] is where the track sits — either the paused position,
  // or the position as of the last refresh while playing.
  //
  // A receiver must **not** reconstruct the position as `now - startedAtEpochMs` the way the stopwatch does. Two
  // devices' clock *offsets* can differ by seconds, which for a stopwatch is invisible and for audio means starting
  // somewhere else entirely. Instead a receiver starts at whatever [positionMs] it was handed and counts forward on
  // its own clock. So only clock *rates* matter, and those agree to parts per million.
  //
  // The timestamp still earns its place: it is what tells a receiver the track is playing rather than paused. The
  // presenter also refreshes the pair every few seconds while playing. That way a screen joining mid-track lands
  // close to the right place instead of at the last pause.
  const factory BoardWidgetConfig.audioPlayer({
    @Default('') String fileId,
    @Default('') String title,
    @Default(1.0) double volume,
    @Default(false) bool loop,
    @Default(0) int positionMs,
    int? startedAtEpochMs,
    int? durationMs,
    // The MIME type the file was uploaded as, captured when it is picked.
    //
    // Only streaming needs it: SoLoud can sniff MP3 and Ogg out of a partial stream, but not WAV or FLAC. So the
    // player has to know which format it has *before* deciding how to load it. Null on a player configured before
    // this field existed, which simply takes the whole-file path.
    String? contentType,
  }) = AudioPlayerConfig;

  // A roll travels as config, not as frames. [rolledAtEpochMs] is the wall-clock
  // anchor the tumble is animated from — the same trick the stopwatch uses for
  // elapsed time — so one widgetUpserted carries a whole roll and the external
  // display and every web viewer land on [face] at the same moment without
  // anyone pushing an animation. [rollSeed] varies the tumble and must advance on
  // every roll; see nextRollSeed in dice_roll.dart.
  const factory BoardWidgetConfig.dice({
    @Default(1) int face,
    @Default(0) int rollSeed,
    int? rolledAtEpochMs,
    @Default(DiceStyle.ivory) DiceStyle style,
  }) = DiceConfig;

  // The flat variant, over an arbitrary range. Same anchor, same guarantee.
  const factory BoardWidgetConfig.numberDice({
    @Default(1) int min,
    @Default(6) int max,
    @Default(1) int value,
    @Default(0) int rollSeed,
    int? rolledAtEpochMs,
  }) = NumberDiceConfig;

  // Stand-in for a widget type this build has never heard of, minted only while
  // decoding live-share frames (see live_share_message.dart) so a mirror can show
  // the rest of a board a newer presenter is sharing. Deliberately not a
  // `fallbackUnion`: stored boards must keep failing on an unknown type, or an
  // older build would load one with blanks and autosave over the real widgets.
  const factory BoardWidgetConfig.unsupported() = UnsupportedConfig;

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
