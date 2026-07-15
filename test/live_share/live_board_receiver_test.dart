import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/live_share/live_board_receiver.dart';

Board _board({String id = 'board_1', double lineSpacing = 64}) => Board(
  id: id,
  title: 'Board',
  backgroundColor: Colors.white,
  isChalkboard: false,
  linePattern: BoardLinePattern.none,
  lineSpacing: lineSpacing,
  lineColor: Colors.grey,
);

BoardWidget _widget(String id, {double x = 0}) =>
    BoardWidget(id: id, config: const BoardWidgetConfig.digitalClock(), x: x, y: 0);

/// A real stroke's JSON, produced by the drawing package itself and pushed
/// through a wire round-trip so whole-number doubles collapse to ints —
/// exactly what arrives over the bus or the backend.
Map<String, dynamic> _strokeJson({double to = 10}) {
  final controller = DrawingController()..setPaintContent(SimpleLine());
  addTearDown(controller.dispose);
  controller
    ..setStyle(color: Colors.black, strokeWidth: 2)
    ..startDraw(const Offset(1, 1))
    ..drawing(Offset(to, to))
    ..endDraw();
  final json = controller.getJsonList().single;
  return jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
}

LiveShareMessage _snapshot({
  int seq = 1,
  String boardId = 'board_1',
  List<BoardWidget> widgets = const [],
  List<Map<String, dynamic>> strokes = const [],
  Map<String, dynamic>? inProgress,
}) => LiveShareMessage.snapshot(
  seq: seq,
  board: _board(id: boardId),
  widgets: widgets,
  strokes: strokes,
  inProgress: inProgress,
);

void main() {
  late LiveBoardReceiver receiver;

  setUp(() {
    receiver = LiveBoardReceiver();
    addTearDown(receiver.dispose);
  });

  group('LiveBoardReceiver', () {
    test('snapshot fully replaces state, including int-collapsed strokes', () {
      receiver.apply(_snapshot(
        widgets: [_widget('w1')],
        strokes: [_strokeJson()],
        inProgress: _strokeJson(to: 20),
      ));

      expect(receiver.board?.id, 'board_1');
      expect(receiver.widgets.single.id, 'w1');
      expect(receiver.drawingController.getJsonList(), hasLength(1));
      expect(receiver.inProgress.value, isNotNull);
    });

    test('boardProps updates the board in place', () {
      receiver
        ..apply(_snapshot())
        ..apply(LiveShareMessage.boardProps(seq: 2, board: _board(lineSpacing: 32)));

      expect(receiver.board?.lineSpacing, 32);
    });

    test('widgetUpserted replaces in place preserving order, or appends', () {
      receiver
        ..apply(_snapshot(widgets: [_widget('w1'), _widget('w2')]))
        ..apply(LiveShareMessage.widgetUpserted(seq: 2, widget: _widget('w1', x: 99)))
        ..apply(LiveShareMessage.widgetUpserted(seq: 3, widget: _widget('w3')));

      expect(receiver.widgets.map((w) => w.id), ['w1', 'w2', 'w3']);
      expect(receiver.widgets.first.x, 99);
    });

    test('strokeCommitted appends and drops the in-progress stroke', () {
      receiver
        ..apply(_snapshot(strokes: [_strokeJson()], inProgress: _strokeJson(to: 20)))
        ..apply(LiveShareMessage.strokeCommitted(seq: 2, stroke: _strokeJson(to: 20)));

      expect(receiver.drawingController.getJsonList(), hasLength(2));
      expect(receiver.inProgress.value, isNull);
    });

    test('drawingSet replaces committed strokes (clear = empty)', () {
      receiver
        ..apply(_snapshot(strokes: [_strokeJson(), _strokeJson(to: 30)]))
        ..apply(const LiveShareMessage.drawingSet(seq: 2, strokes: []));

      expect(receiver.drawingController.getJsonList(), isEmpty);
    });

    test('clear returns to idle', () {
      receiver
        ..apply(_snapshot(widgets: [_widget('w1')], strokes: [_strokeJson()]))
        ..apply(const LiveShareMessage.clear(seq: 2));

      expect(receiver.board, isNull);
      expect(receiver.widgets, isEmpty);
      expect(receiver.drawingController.getJsonList(), isEmpty);
    });

    test('a sequence gap freezes deltas, fires onGapDetected once, and heals on snapshot', () {
      var gaps = 0;
      receiver
        ..onGapDetected = (() => gaps++)
        ..apply(_snapshot(seq: 5))
        ..apply(LiveShareMessage.boardProps(seq: 6, board: _board(lineSpacing: 32)));
      expect(receiver.board?.lineSpacing, 32);

      // seq 7 lost in transit.
      receiver.apply(LiveShareMessage.boardProps(seq: 8, board: _board(lineSpacing: 16)));
      expect(receiver.board?.lineSpacing, 32, reason: 'delta after a gap must not apply');
      expect(receiver.needsResync, isTrue);
      expect(gaps, 1);

      receiver.apply(LiveShareMessage.boardProps(seq: 9, board: _board(lineSpacing: 8)));
      expect(receiver.board?.lineSpacing, 32);
      expect(gaps, 1, reason: 'one resync request per gap');

      receiver.apply(_snapshot(seq: 12, widgets: [_widget('w1')]));
      expect(receiver.needsResync, isFalse);
      receiver.apply(LiveShareMessage.boardProps(seq: 13, board: _board(lineSpacing: 4)));
      expect(receiver.board?.lineSpacing, 4);
    });

    test('a delta with no snapshot baseline requests a resync', () {
      var gaps = 0;
      receiver
        ..onGapDetected = (() => gaps++)
        ..apply(LiveShareMessage.boardProps(seq: 3, board: _board()));

      expect(receiver.board, isNull);
      expect(gaps, 1);
    });

    test('unnumbered frames (seq 0) bypass gap tracking', () {
      receiver
        ..apply(_snapshot(seq: 5))
        ..apply(const LiveShareMessage.clear());

      expect(receiver.board, isNull);
    });
  });
}
