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

/// A snapshot as a newer app version sends it: the middle widget carries a
/// config type this build has never heard of. Widget configs are a union
/// discriminated on `runtimeType`, so this is what a board from the future looks
/// like arriving at a mirror.
Map<String, dynamic> _snapshotFromTheFuture() {
  final message = LiveShareMessage.snapshot(
    seq: 3,
    board: _board(),
    widgets: const [
      BoardWidget(id: 'w1', config: BoardWidgetConfig.digitalClock(), x: 100, y: 200),
      BoardWidget(id: 'w2', config: BoardWidgetConfig.digitalClock(), x: 300, y: 400, rotation: 0.5, scale: 2),
      BoardWidget(id: 'w3', config: BoardWidgetConfig.digitalClock(), x: 500, y: 600),
    ],
    strokes: const [],
  );
  final json = jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>;
  final widget = (json['widgets']! as List<dynamic>)[1]! as Map<String, dynamic>;
  (widget['config']! as Map<String, dynamic>)['runtimeType'] = 'hologram';
  return json;
}

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
        fullScreenWidgetId: 'w2',
      );

      final decoded = LiveShareMessage.fromJson(jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>);

      final snapshot = decoded as LiveShareSnapshot;
      expect(snapshot.seq, 7);
      expect(snapshot.board, _board());
      expect(snapshot.widgets, widgets);
      expect(snapshot.strokes.single['type'], 'SimpleLine');
      expect(snapshot.inProgress, {'type': 'Eraser'});
      expect(snapshot.fileIds, ['file-1']);
      expect(snapshot.fullScreenWidgetId, 'w2');
    });

    test('fullScreen survives a wire round-trip, both entering and leaving', () {
      LiveShareMessage roundTrip(LiveShareMessage message) =>
          LiveShareMessage.fromJson(jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>);

      expect(roundTrip(const LiveShareMessage.fullScreen(seq: 9, widgetId: 'w1')).seq, 9);
      expect((roundTrip(const LiveShareMessage.fullScreen(seq: 9, widgetId: 'w1')) as LiveShareFullScreen).widgetId, 'w1');
      expect((roundTrip(const LiveShareMessage.fullScreen(seq: 10)) as LiveShareFullScreen).widgetId, isNull);
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
      expect(typeOf(const LiveShareMessage.fullScreen()), 'fullScreen');
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

    test('a widget type from a newer version costs that widget, not the frame', () {
      final decoded = LiveShareMessage.fromJson(_snapshotFromTheFuture()) as LiveShareSnapshot;

      expect(decoded.widgets.map((w) => w.id), ['w1', 'w2', 'w3']);
      expect(decoded.widgets.first.config, const BoardWidgetConfig.digitalClock());
      expect(decoded.widgets.last.config, const BoardWidgetConfig.digitalClock());
    });

    test('the stand-in keeps the placement, so it lands where the real widget was', () {
      final decoded = LiveShareMessage.fromJson(_snapshotFromTheFuture()) as LiveShareSnapshot;

      final standIn = decoded.widgets[1];
      expect(standIn.config, const BoardWidgetConfig.unsupported());
      expect(standIn.x, 300);
      expect(standIn.y, 400);
      expect(standIn.rotation, 0.5);
      expect(standIn.scale, 2);
    });

    test('widgetsSet gets the same tolerance, and drops what it cannot place', () {
      final decoded = LiveShareMessage.fromJson({
        'type': 'widgetsSet',
        'seq': 2,
        'widgets': [
          {
            'id': 'w1',
            'config': {'runtimeType': 'digitalClock'},
            'x': 1.0,
            'y': 2.0,
          },
          // No id to place it by, and not a map at all.
          {
            'config': {'runtimeType': 'hologram'},
          },
          'a widget, allegedly',
        ],
      }) as LiveShareWidgetsSet;

      expect(decoded.widgets.map((w) => w.id), ['w1']);
    });

    test('widgetUpserted of a type from a newer version still upserts', () {
      final decoded = LiveShareMessage.fromJson({
        'type': 'widgetUpserted',
        'seq': 4,
        'widget': {
          'id': 'w9',
          'config': {'runtimeType': 'hologram', 'glow': true},
          'x': 12.0,
          'y': 34.0,
        },
      }) as LiveShareWidgetUpserted;

      expect(decoded.widget.id, 'w9');
      expect(decoded.widget.config, const BoardWidgetConfig.unsupported());
      expect(decoded.widget.x, 12);
    });

    test('tolerance stops at the widget list — a frame broken elsewhere still fails', () {
      // Which is what the transport reports as unsupported content, rather than
      // dropping in silence.
      expect(
        () => LiveShareMessage.fromJson({
          'type': 'snapshot',
          'seq': 1,
          'board': 'not a board',
          'widgets': <dynamic>[],
          'strokes': <dynamic>[],
        }),
        throwsA(anything),
      );
    });
  });
}
