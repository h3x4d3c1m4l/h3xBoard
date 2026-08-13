import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';

part 'board_content.freezed.dart';
part 'board_content.g.dart';

/// The full, persistable state of a board: its sub-boards, the widgets placed
/// on them, and the drawing strokes per sub-board. Serialized into the `data`
/// blob the server stores for each board.
@freezed
abstract class BoardContent with _$BoardContent {

  const factory BoardContent({
    @Default(<Board>[]) List<Board> subBoards,
    @Default('') String activeSubBoardId,
    @Default(<BoardWidget>[]) List<BoardWidget> widgets,
    @Default(<String, List<Map<String, dynamic>>>{}) Map<String, List<Map<String, dynamic>>> drawings,
  }) = _BoardContent;

  factory BoardContent.fromJson(Map<String, dynamic> json) => _$BoardContentFromJson(json);

}

/// Thrown when a stored board can't be read by this build of the app.
///
/// In practice that means the board was saved by a newer version: widget
/// configs are a discriminated union, so a widget type this build has never
/// heard of (or a field that changed shape) makes [BoardContent.fromJson]
/// throw. The board itself is fine — this app just can't render it yet.
class UnsupportedBoardContentException implements Exception {

  /// The deserialization failure underneath, kept for logging.
  final Object cause;

  const UnsupportedBoardContentException(this.cause);

  @override
  String toString() => 'UnsupportedBoardContentException: $cause';

}

/// Reads the persisted `data` blob of a board into [BoardContent].
///
/// Every caller goes through here rather than [BoardContent.fromJson] directly:
/// a malformed or too-new blob must surface as an
/// [UnsupportedBoardContentException] the board screen can explain, not as a
/// raw `CheckedFromJsonException` escaping into a widget build (which is an
/// error screen, red in debug and gray in release).
BoardContent parseBoardContent(Map<String, dynamic> data) {
  if (data.isEmpty) return const BoardContent();
  try {
    return BoardContent.fromJson(data);
  } catch (e) {
    throw UnsupportedBoardContentException(e);
  }
}
