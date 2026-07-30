import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/laser_pointer.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';

Board _board({String id = 'board_1'}) => Board(
  id: id,
  title: 'Board',
  backgroundColor: Colors.white,
  isChalkboard: false,
  linePattern: BoardLinePattern.grid,
  lineSpacing: 64,
  // A plain Color, not fluent's Colors.grey (a ShadedColor): the wire
  // round-trip decodes to Color, and ShadedColor equality is asymmetric.
  lineColor: const Color(0xFF808080),
);

void main() {
  group('LiveShareMessage', () {
    test('snapshot survives a wire round-trip (jsonEncode/jsonDecode)', () {
      final widgets = [
        const BoardWidget(id: 'w1', config: BoardWidgetConfig.digitalClock(), x: 100, y: 200),
        const BoardWidget(id: 'w2', config: BoardWidgetConfig.image(fileId: 'file-1'), x: 10, y: 20),
      ];
      final message = LiveShareMessage.snapshot(
        seq: 7,
        board: _board(),
        widgets: widgets,
        strokes: [
          {
            'type': 'SimpleLine',
            'startPoint': {'dx': 1.0, 'dy': 2.5},
          },
        ],
        inProgress: {'type': 'Eraser'},
        fileIds: ['file-1'],
      );

      final decoded = LiveShareMessage.fromJson(jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>);

      final snapshot = decoded as LiveShareSnapshot;
      expect(snapshot.seq, 7);
      expect(snapshot.board, _board());
      expect(snapshot.widgets, widgets);
      expect(snapshot.strokes.single['type'], 'SimpleLine');
      expect(snapshot.inProgress, {'type': 'Eraser'});
      expect(snapshot.fileIds, ['file-1']);
    });

    test('uses the wire type names the server dispatches on', () {
      String typeOf(LiveShareMessage message) => message.toJson()['type'] as String;

      expect(typeOf(LiveShareMessage.snapshot(board: _board(), widgets: const [], strokes: const [])), 'snapshot');
      expect(typeOf(LiveShareMessage.boardProps(board: _board())), 'boardProps');
      expect(
        typeOf(const LiveShareMessage.widgetUpserted(
          widget: BoardWidget(id: 'w', config: BoardWidgetConfig.digitalClock(), x: 0, y: 0),
        )),
        'widgetUpserted',
      );
      expect(typeOf(const LiveShareMessage.widgetsSet(widgets: [])), 'widgetsSet');
      expect(typeOf(const LiveShareMessage.strokeProgress()), 'strokeProgress');
      expect(typeOf(const LiveShareMessage.strokeCommitted(stroke: {})), 'strokeCommitted');
      expect(typeOf(const LiveShareMessage.drawingSet(strokes: [])), 'drawingSet');
      expect(typeOf(const LiveShareMessage.clear()), 'clear');
      expect(typeOf(const LiveShareMessage.laser()), 'laser');
      expect(typeOf(const LiveShareMessage.ping()), 'ping');
      expect(typeOf(const LiveShareMessage.resyncRequest()), 'resyncRequest');
    });

    test('laser survives a wire round-trip', () {
      const message = LiveShareMessage.laser(
        seq: 12,
        pointer: LaserPointer(x: 960.5, y: 540.25, color: LaserColor.magenta),
      );

      final decoded = LiveShareMessage.fromJson(jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>);

      expect(decoded, message);
    });

    test('a laser colour a newer client added decodes as red rather than failing', () {
      final decoded = LiveShareMessage.fromJson({
        'type': 'laser',
        'seq': 3,
        'pointer': {'x': 1.0, 'y': 2.0, 'color': 'chartreuse'},
      });

      expect((decoded as LiveShareLaser).pointer?.color, LaserColor.red);
    });

    test('a laser frame with no pointer means the laser was put away', () {
      final decoded = LiveShareMessage.fromJson({'type': 'laser', 'seq': 5});
      expect((decoded as LiveShareLaser).pointer, isNull);
    });

    test('decodes server-origin frames', () {
      LiveShareMessage decode(String json) => LiveShareMessage.fromJson(jsonDecode(json) as Map<String, dynamic>);

      expect(
        decode('{"v":1,"seq":0,"origin":"server","type":"hello","state":"waiting"}'),
        const LiveShareMessage.hello(state: LiveShareViewerState.waiting),
      );
      expect(
        decode('{"type":"sessionEnded","reason":"expired"}'),
        const LiveShareMessage.sessionEnded(reason: LiveShareEndReason.expired),
      );
      expect(
        decode('{"type":"viewerCount","count":3}'),
        const LiveShareMessage.viewerCount(count: 3),
      );
    });

    test('decodes unrecognised frame types as LiveShareUnknown', () {
      final decoded = LiveShareMessage.fromJson({'v': 1, 'seq': 4, 'type': 'somethingNew', 'data': 42});
      expect(decoded, isA<LiveShareUnknown>());
      expect((decoded as LiveShareUnknown).seq, 4);
    });
  });
}
