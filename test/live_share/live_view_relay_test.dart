import 'dart:async';
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/board_asset_resolver.dart';
import 'package:h3xboard/services/live_share/live_share_hub.dart';
import 'package:h3xboard/services/live_share/live_view_client.dart';
import 'package:h3xboard/services/live_share/live_view_relay.dart';

Board _board({String id = 'board_1'}) => Board(
  id: id,
  title: 'Board',
  backgroundColor: Colors.white,
  isChalkboard: false,
  linePattern: BoardLinePattern.none,
  lineSpacing: 64,
  lineColor: Colors.grey,
);

LiveShareMessage _snapshot({int seq = 1, String boardId = 'board_1'}) =>
    LiveShareMessage.snapshot(seq: seq, board: _board(id: boardId), widgets: const [], strokes: const []);

class _StubAssets implements BoardAssetResolver {

  @override
  Future<Uint8List> load(String fileId) async => Uint8List(0);

  @override
  Future<Stream<List<int>>>? openStream(String fileId) => null;

}

class _RecordingSink implements LiveShareSink {

  @override
  final bool isDeviceLocal;

  final List<LiveShareMessage> messages = [];

  _RecordingSink({required this.isDeviceLocal});

  @override
  void send(LiveShareMessage message) => messages.add(message);

  /// Messages received since the last call.
  List<LiveShareMessage> drain() {
    final drained = List.of(messages);
    messages.clear();
    return drained;
  }

}

void main() {
  late LiveShareHub hub;
  late _RecordingSink display;
  late _RecordingSink server;
  late StreamController<LiveShareMessage> messages;
  late ValueNotifier<LiveViewState> state;
  late int resyncRequests;
  LiveViewRelay? relay;

  setUp(() {
    hub = LiveShareHub();
    display = _RecordingSink(isDeviceLocal: true);
    server = _RecordingSink(isDeviceLocal: false);
    hub
      ..addSink(display)
      ..addSink(server);
    messages = StreamController<LiveShareMessage>.broadcast();
    state = ValueNotifier(LiveViewState.connecting);
    resyncRequests = 0;
  });

  tearDown(() {
    relay?.dispose();
    relay = null;
    unawaited(messages.close());
    state.dispose();
  });

  LiveViewRelay createRelay() => relay = LiveViewRelay(
    hub: hub,
    messages: messages.stream,
    state: state,
    requestResync: () => resyncRequests++,
    assets: _StubAssets(),
  );

  /// Pushes [message] through the viewer's transport and lets the relay's
  /// stream subscription run.
  Future<void> receive(LiveShareMessage message) async {
    messages.add(message);
    await Future<void>.delayed(Duration.zero);
  }

  group('LiveViewRelay', () {
    test('relays watched frames to screens attached to this device only', () async {
      createRelay();

      await receive(_snapshot());
      await receive(const LiveShareMessage.laser(seq: 2));

      expect(display.drain(), [isA<LiveShareSnapshot>(), isA<LiveShareLaser>()]);
      // The watched board belongs to another presenter — it must never go out
      // under this user's own share code.
      expect(server.messages, isEmpty);
    });

    test('answers a snapshot request with the last snapshot and asks for a fresh one', () async {
      createRelay();
      await receive(_snapshot(seq: 7, boardId: 'board_7'));
      display.drain();

      // What a display being plugged in mid-session triggers.
      hub.requestSnapshot();

      expect(display.drain(), [isA<LiveShareSnapshot>().having((s) => s.board.id, 'board.id', 'board_7')]);
      expect(resyncRequests, 1);
    });

    test('answers a snapshot request before any snapshot with idle', () async {
      createRelay();

      hub.requestSnapshot();

      expect(display.drain(), [isA<LiveShareClear>()]);
      expect(resyncRequests, 1);
    });

    test('blanks attached screens when the session ends for good', () async {
      createRelay();
      await receive(_snapshot());
      display.drain();

      state.value = LiveViewState.ended;

      expect(display.drain(), [isA<LiveShareClear>()]);
      // The board is gone, so a display connecting afterwards gets idle too.
      hub.requestSnapshot();
      expect(display.drain(), [isA<LiveShareClear>()]);
    });

    test('keeps the board up while the presenter is only away', () async {
      createRelay();
      await receive(_snapshot());
      display.drain();

      state
        ..value = LiveViewState.paused
        ..value = LiveViewState.reconnecting;

      expect(display.messages, isEmpty);
    });

    test('stops relaying and blanks attached screens on dispose', () async {
      createRelay();
      await receive(_snapshot());
      display.drain();

      final disposed = relay!;
      relay = null;
      disposed.dispose();

      expect(display.drain(), [isA<LiveShareClear>()]);
      expect(hub.hasPresenter, isFalse);

      await receive(const LiveShareMessage.laser(seq: 2));
      expect(display.messages, isEmpty);
    });
  });
}
