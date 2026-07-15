import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';

part 'live_share_message.freezed.dart';
part 'live_share_message.g.dart';

/// What a viewer is looking at, as told by the server's `hello` frame.
/// [full] means the session hit its viewer cap; like [notFound] the server
/// closes the socket right after.
enum LiveShareViewerState { live, waiting, notFound, full }

/// Why a share session ended.
enum LiveShareEndReason { stopped, expired }

/// One frame of the live-share protocol: the unified message vocabulary spoken
/// between a presenting board screen and every mirror of it — the local
/// external-display isolate (over the plugin bus) and web viewers (relayed
/// through the backend).
///
/// The flow is snapshot + deltas: a [LiveShareSnapshot] fully replaces the
/// receiver's state, every other presenter message mutates it incrementally.
/// [seq] increases by one per presenter message within a sharing session, so a
/// receiver on a lossy transport can detect a gap and request a resync; a
/// snapshot resets the baseline. Frames the server originates (hello, session
/// lifecycle, viewer count) carry `seq: 0` and are excluded from gap tracking.
///
/// The backend relays presenter frames verbatim and reads only the envelope
/// fields `type`, `seq` and — on snapshots — [LiveShareSnapshot.fileIds]; the
/// board payload stays opaque to the server. Renaming any JSON key here is a
/// protocol change that must be mirrored in h3xBoardServer.
///
/// Unrecognised frame types decode as [LiveShareUnknown] instead of throwing,
/// so an older client just skips messages a newer peer added.
@Freezed(unionKey: 'type', fallbackUnion: 'unknown')
sealed class LiveShareMessage with _$LiveShareMessage {

  /// Full render state of the active sub-board; replaces everything shown.
  /// A snapshot whose [board] id differs from the one on screen is a board
  /// switch (receivers transition through black); same id = in-place refresh.
  /// [fileIds] lists every uploaded file the payload references (image
  /// widgets, background image) — the server stores it as the allowlist for
  /// anonymous viewer file downloads.
  const factory LiveShareMessage.snapshot({
    @Default(1) int v,
    @Default(0) int seq,
    required Board board,
    required List<BoardWidget> widgets,
    required List<Map<String, dynamic>> strokes,
    Map<String, dynamic>? inProgress,
    @Default(<String>[]) List<String> fileIds,
  }) = LiveShareSnapshot;

  /// The active sub-board's appearance changed (background, line pattern, …)
  /// without switching boards. [board] keeps the same id.
  const factory LiveShareMessage.boardProps({
    @Default(1) int v,
    @Default(0) int seq,
    required Board board,
  }) = LiveShareBoardProps;

  /// One widget was added or changed in place. Receivers replace the widget
  /// with the same id keeping its position in the list (= render order), or
  /// append when it is new.
  const factory LiveShareMessage.widgetUpserted({
    @Default(1) int v,
    @Default(0) int seq,
    required BoardWidget widget,
  }) = LiveShareWidgetUpserted;

  /// The visible widget list changed in a way a single upsert can't express
  /// (remove, reorder, several at once). Full replace, in render order.
  const factory LiveShareMessage.widgetsSet({
    @Default(1) int v,
    @Default(0) int seq,
    required List<BoardWidget> widgets,
  }) = LiveShareWidgetsSet;

  /// The in-progress (not yet committed) stroke, replacing the previous
  /// in-progress stroke wholesale. `null` means it was cancelled without
  /// committing. Sent per frame locally, throttled over the network.
  const factory LiveShareMessage.strokeProgress({
    @Default(1) int v,
    @Default(0) int seq,
    Map<String, dynamic>? stroke,
  }) = LiveShareStrokeProgress;

  /// A stroke was committed: append it to the drawing and drop any
  /// in-progress stroke (it is this one, finished).
  const factory LiveShareMessage.strokeCommitted({
    @Default(1) int v,
    @Default(0) int seq,
    required Map<String, dynamic> stroke,
  }) = LiveShareStrokeCommitted;

  /// The committed drawing changed in a way an append can't express (undo,
  /// redo, clear = `[]`). Full replace.
  const factory LiveShareMessage.drawingSet({
    @Default(1) int v,
    @Default(0) int seq,
    required List<Map<String, dynamic>> strokes,
  }) = LiveShareDrawingSet;

  /// No board is open (the presenter left the board screen). External display
  /// shows its idle placeholder, web viewers show "waiting".
  const factory LiveShareMessage.clear({
    @Default(1) int v,
    @Default(0) int seq,
  }) = LiveShareClear;

  /// Server → viewer: first frame after connecting, telling the viewer what
  /// it is looking at. A state this client doesn't know decodes as [notFound]
  /// (terminal) rather than failing the frame.
  const factory LiveShareMessage.hello({
    @Default(1) int v,
    @Default(0) int seq,
    @JsonKey(unknownEnumValue: LiveShareViewerState.notFound) required LiveShareViewerState state,
  }) = LiveShareHello;

  /// Server → viewer: the presenter's connection dropped; the session is in
  /// its reconnect grace window.
  const factory LiveShareMessage.sessionPaused({
    @Default(1) int v,
    @Default(0) int seq,
  }) = LiveShareSessionPaused;

  /// Server → viewer: the presenter reconnected and resumed the session.
  const factory LiveShareMessage.sessionResumed({
    @Default(1) int v,
    @Default(0) int seq,
  }) = LiveShareSessionResumed;

  /// Server → viewer: the session is over (presenter stopped sharing, or the
  /// grace window expired). Terminal — no more frames follow.
  const factory LiveShareMessage.sessionEnded({
    @Default(1) int v,
    @Default(0) int seq,
    required LiveShareEndReason reason,
  }) = LiveShareSessionEnded;

  /// Server → viewer and (as an RPC notification) server → presenter: how
  /// many viewers are currently watching.
  const factory LiveShareMessage.viewerCount({
    @Default(1) int v,
    @Default(0) int seq,
    required int count,
  }) = LiveShareViewerCount;

  /// Viewer → server: presence heartbeat keeping this viewer counted.
  const factory LiveShareMessage.ping({
    @Default(1) int v,
    @Default(0) int seq,
  }) = LiveSharePing;

  /// Viewer → server: a sequence gap was detected; please have the presenter
  /// send a fresh snapshot.
  const factory LiveShareMessage.resyncRequest({
    @Default(1) int v,
    @Default(0) int seq,
  }) = LiveShareResyncRequest;

  /// Fallback for frame types this client doesn't know. Skipped by receivers.
  const factory LiveShareMessage.unknown({
    @Default(1) int v,
    @Default(0) int seq,
  }) = LiveShareUnknown;

  factory LiveShareMessage.fromJson(Map<String, dynamic> json) => _$LiveShareMessageFromJson(json);

}
