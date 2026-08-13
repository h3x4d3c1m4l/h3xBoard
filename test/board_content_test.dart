import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_content.dart';
import 'package:h3xboard/models/board_widget.dart';

/// A board exactly as this build would save it.
const _content = BoardContent(
  subBoards: [
    Board(
      id: 'board_1',
      title: 'Board 1',
      backgroundColor: Colors.white,
      isChalkboard: false,
      linePattern: BoardLinePattern.none,
      lineSpacing: 40,
      lineColor: Colors.black,
    ),
  ],
  activeSubBoardId: 'board_1',
  widgets: [
    BoardWidget(id: 'w1', config: BoardWidgetConfig.digitalClock(), x: 960, y: 540),
  ],
);

/// [content] as the server hands it back: [BoardContent.toJson] leaves nested
/// models as objects (json_serializable's default), so the blob only becomes
/// plain maps once it has been through JSON — which is the form
/// [parseBoardContent] is given.
Map<String, dynamic> _asStored(BoardContent content) =>
    jsonDecode(jsonEncode(content.toJson())) as Map<String, dynamic>;

/// The same board as saved by a newer version of the app: its widget carries a
/// config type this build has never heard of. Widget configs are a union
/// discriminated on `runtimeType`, so this is what "a board from the future"
/// looks like on the wire.
Map<String, dynamic> _boardFromTheFuture() {
  final json = _asStored(_content);
  final widget = (json['widgets']! as List<dynamic>).first! as Map<String, dynamic>;
  (widget['config']! as Map<String, dynamic>)['runtimeType'] = 'hologram';
  return json;
}

void main() {

  group('parseBoardContent', () {

    test('reads a board this build understands', () {
      expect(parseBoardContent(_asStored(_content)), _content);
    });

    test('an empty blob is a blank board, not a failure', () {
      expect(parseBoardContent(const {}), const BoardContent());
    });

    test('a widget type from a newer version throws instead of escaping into the widget tree', () {
      expect(
        () => parseBoardContent(_boardFromTheFuture()),
        throwsA(isA<UnsupportedBoardContentException>()),
      );
    });

    test('a structurally broken blob is reported the same way', () {
      expect(
        () => parseBoardContent(const {'widgets': 'not a list'}),
        throwsA(isA<UnsupportedBoardContentException>()),
      );
    });

  });

}
