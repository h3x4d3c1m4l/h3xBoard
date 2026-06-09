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
