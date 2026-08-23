import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/laser_pointer.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/board_asset_resolver.dart';
import 'package:h3xboard/services/live_share/live_board_publisher.dart';
import 'package:h3xboard/services/live_share/live_share_hub.dart';
import 'package:mobx/mobx.dart';

Board _board({String id = 'board_1', double lineSpacing = 64, String? backgroundFileId}) => Board(
  id: id,
  title: 'Board',
  backgroundColor: Colors.white,
  isChalkboard: false,
  linePattern: BoardLinePattern.none,
  lineSpacing: lineSpacing,
  lineColor: Colors.grey,
  backgroundFileId: backgroundFileId,
);

BoardWidget _widget(String id, {double x = 0, BoardWidgetConfig config = const BoardWidgetConfig.digitalClock()}) =>
    BoardWidget(id: id, config: config, x: x, y: 0);

class _StubAssets implements BoardAssetResolver {

  @override
  Future<Uint8List> load(String fileId) async => Uint8List(0);

  @override
  Future<Stream<List<int>>>? openStream(String fileId) => null;

}

class _RecordingSink implements LiveShareSink {

  final List<LiveShareMessage> messages = [];

  @override
  bool get isDeviceLocal => true;

  @override
  void send(LiveShareMessage message) => messages.add(message);

  LiveShareMessage get last => messages.last;

  /// Messages published since the last call.
  List<LiveShareMessage> drain() {
    final drained = List.of(messages);
    messages.clear();
    return drained;
  }

}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LiveShareHub hub;
  late _RecordingSink sink;
  late DrawingController drawingController;
  late Observable<Board> board;
  late Observable<List<BoardWidget>> widgets;
  late Observable<String?> fullScreenWidgetId;
  late Observable<bool> isLoading;
  late ValueNotifier<LaserPointer?> laser;
  late ValueNotifier<bool> audioToViewers;
  LiveBoardPublisher? publisher;

  setUp(() {
    hub = LiveShareHub();
    sink = _RecordingSink();
    hub.addSink(sink);
    drawingController = DrawingController()..setPaintContent(SimpleLine());
    board = Observable(_board());
    widgets = Observable(const []);
    fullScreenWidgetId = Observable(null);
    isLoading = Observable(false);
    laser = ValueNotifier(null);
    audioToViewers = ValueNotifier<bool>(false);
  });

  tearDown(() {
    publisher?.dispose();
    publisher = null;
    drawingController.dispose();
    laser.dispose();
    audioToViewers.dispose();
  });

  LiveBoardPublisher createPublisher() => publisher = LiveBoardPublisher(
    hub: hub,
    drawingController: drawingController,
    board: () => board.value,
    widgets: () => widgets.value,
    fullScreenWidgetId: () => fullScreenWidgetId.value,
    isLoading: () => isLoading.value,
    laser: laser,
    audioToViewers: () => audioToViewers.value,
    assets: _StubAssets(),
  );

  void drawStroke({double to = 10}) {
    drawingController
      ..startDraw(const Offset(1, 1))
      ..drawing(Offset(to, to))
      ..endDraw();
  }

  group('LiveBoardPublisher', () {
    test('publishes an initial snapshot and nothing while loading', () {
      runInAction(() => isLoading.value = true);
      createPublisher();
      expect(sink.messages, isEmpty);

      runInAction(() => isLoading.value = false);
      expect(sink.drain().single, isA<LiveShareSnapshot>());
    });

    test('single widget change in place becomes an upsert', () {
      runInAction(() => widgets.value = [_widget('w1'), _widget('w2')]);
      createPublisher();
      sink.drain();

      runInAction(() => widgets.value = [_widget('w1', x: 50), _widget('w2')]);

      final upserted = sink.drain().single as LiveShareWidgetUpserted;
      expect(upserted.widget.id, 'w1');
      expect(upserted.widget.x, 50);
    });

    test('appending a widget becomes an upsert', () {
      runInAction(() => widgets.value = [_widget('w1')]);
      createPublisher();
      sink.drain();

      runInAction(() => widgets.value = [_widget('w1'), _widget('w2')]);

      expect((sink.drain().single as LiveShareWidgetUpserted).widget.id, 'w2');
    });

    test('removal and reorder fall back to widgetsSet', () {
      runInAction(() => widgets.value = [_widget('w1'), _widget('w2')]);
      createPublisher();
      sink.drain();

      runInAction(() => widgets.value = [_widget('w2')]);
      expect(sink.drain().single, isA<LiveShareWidgetsSet>());

      runInAction(() => widgets.value = [_widget('w2'), _widget('w1')].reversed.toList());
      expect(sink.drain().single, isA<LiveShareWidgetsSet>());
    });

    test('appearance change on the same board becomes boardProps', () {
      createPublisher();
      sink.drain();

      runInAction(() => board.value = _board(lineSpacing: 32));

      final props = sink.drain().single as LiveShareBoardProps;
      expect(props.board.lineSpacing, 32);
    });

    test('a board id change publishes a fresh snapshot', () {
      createPublisher();
      sink.drain();

      runInAction(() => board.value = _board(id: 'board_2'));

      expect((sink.drain().single as LiveShareSnapshot).board.id, 'board_2');
    });

    test('showing a widget full screen becomes a fullScreen delta', () {
      runInAction(() => widgets.value = [_widget('w1')]);
      createPublisher();
      sink.drain();

      runInAction(() => fullScreenWidgetId.value = 'w1');
      expect((sink.drain().single as LiveShareFullScreen).widgetId, 'w1');

      runInAction(() => fullScreenWidgetId.value = null);
      expect((sink.drain().single as LiveShareFullScreen).widgetId, isNull);
    });

    test('a widget added and shown full screen at once is sent before the mode naming it', () {
      createPublisher();
      sink.drain();

      runInAction(() {
        widgets.value = [_widget('w1')];
        fullScreenWidgetId.value = 'w1';
      });

      final messages = sink.drain();
      expect(messages, hasLength(2));
      expect((messages[0] as LiveShareWidgetUpserted).widget.id, 'w1');
      expect((messages[1] as LiveShareFullScreen).widgetId, 'w1');
    });

    test('a snapshot carries the full-screen mode', () {
      runInAction(() {
        widgets.value = [_widget('w1')];
        fullScreenWidgetId.value = 'w1';
      });
      createPublisher();

      expect((sink.drain().single as LiveShareSnapshot).fullScreenWidgetId, 'w1');
    });

    test('a referenced-file change forces a snapshot (viewer file allowlist)', () {
      createPublisher();
      sink.drain();

      runInAction(() => widgets.value = [_widget('img', config: const BoardWidgetConfig.image(fileId: 'file-1'))]);
      expect((sink.drain().single as LiveShareSnapshot).fileIds, ['file-1']);

      runInAction(() => board.value = _board(backgroundFileId: 'file-2'));
      expect((sink.drain().single as LiveShareSnapshot).fileIds, containsAll(['file-1', 'file-2']));
    });

    test('a sound pad is in the allowlist, or its audio 404s for every viewer', () {
      createPublisher();
      sink.drain();

      runInAction(() => widgets.value = [_widget('pad', config: const BoardWidgetConfig.soundPad(fileId: 'clap-1'))]);

      expect((sink.drain().single as LiveShareSnapshot).fileIds, contains('clap-1'));
    });

    test('the audio routing rides along on the snapshot, for a screen joining late', () {
      // A viewer arriving mid-session would otherwise stay silent until the
      // presenter next touched the setting.
      audioToViewers.value = true;
      createPublisher();

      expect((sink.drain().single as LiveShareSnapshot).audioToViewers, isTrue);
    });

    // The testWidgets bodies below dispose the publisher themselves: its
    // periodic safety-snapshot timer would otherwise still be pending when
    // the fake-async zone checks for leaked timers (which runs before
    // tearDown callbacks get the chance to cancel it).

    testWidgets('a finished stroke becomes strokeCommitted', (tester) async {
      createPublisher();
      sink.drain();

      drawStroke();
      await tester.pump();

      expect(sink.drain().whereType<LiveShareStrokeCommitted>(), hasLength(1));
      publisher!.dispose();
      publisher = null;
    });

    testWidgets('undo/clear-style rebuilds become drawingSet', (tester) async {
      createPublisher();
      drawStroke();
      await tester.pump();
      sink.drain();

      drawingController.clear();
      await tester.pump();

      expect((sink.drain().single as LiveShareDrawingSet).strokes, isEmpty);
      publisher!.dispose();
      publisher = null;
    });

    testWidgets('mid-stroke motion streams strokeProgress frames', (tester) async {
      createPublisher();
      sink.drain();

      drawingController
        ..startDraw(const Offset(1, 1))
        ..drawing(const Offset(5, 5));
      await tester.pump();

      final progress = sink.drain().whereType<LiveShareStrokeProgress>().single;
      expect(progress.stroke, isNotNull);

      drawingController
        ..drawing(const Offset(9, 9))
        ..endDraw();
      await tester.pump();

      // The commit supersedes the in-progress stroke; no cancel frame follows.
      final afterEnd = sink.drain();
      expect(afterEnd.whereType<LiveShareStrokeCommitted>(), hasLength(1));
      expect(afterEnd.whereType<LiveShareStrokeProgress>().where((m) => m.stroke == null), isEmpty);
      publisher!.dispose();
      publisher = null;
    });

    testWidgets('moving the laser publishes a laser frame', (tester) async {
      createPublisher();
      sink.drain();

      laser.value = const LaserPointer(x: 100, y: 200, color: LaserColor.green);
      await tester.pump();

      final frame = sink.drain().whereType<LiveShareLaser>().single;
      expect(frame.pointer, const LaserPointer(x: 100, y: 200, color: LaserColor.green));
      publisher!.dispose();
      publisher = null;
    });

    testWidgets('putting the laser away publishes a null pointer', (tester) async {
      createPublisher();
      laser.value = const LaserPointer(x: 10, y: 10, color: LaserColor.red);
      await tester.pump();
      sink.drain();

      laser.value = null;
      await tester.pump();

      expect(sink.drain().whereType<LiveShareLaser>().single.pointer, isNull);
      publisher!.dispose();
      publisher = null;
    });

    testWidgets('several moves in one frame publish only the last position', (tester) async {
      createPublisher();
      sink.drain();

      laser
        ..value = const LaserPointer(x: 1, y: 1, color: LaserColor.red)
        ..value = const LaserPointer(x: 2, y: 2, color: LaserColor.red)
        ..value = const LaserPointer(x: 3, y: 3, color: LaserColor.red);
      await tester.pump();

      final frames = sink.drain().whereType<LiveShareLaser>();
      expect(frames, hasLength(1));
      expect(frames.single.pointer?.x, 3);
      publisher!.dispose();
      publisher = null;
    });

    test('a snapshot carries the current laser so a joining viewer sees the dot', () {
      laser.value = const LaserPointer(x: 42, y: 24, color: LaserColor.magenta);
      createPublisher();

      expect((sink.drain().single as LiveShareSnapshot).laser?.x, 42);
    });

    test('seq increases monotonically across message types', () {
      createPublisher();
      runInAction(() => board.value = _board(lineSpacing: 32));
      runInAction(() => widgets.value = [_widget('w1')]);

      final seqs = [
        for (final m in sink.drain())
          switch (m) {
            LiveShareSnapshot s => s.seq,
            LiveShareBoardProps s => s.seq,
            LiveShareWidgetUpserted s => s.seq,
            _ => fail('unexpected message $m'),
          },
      ];
      expect(seqs, [1, 2, 3]);
    });

    test('hub.requestSnapshot() republishes the full state', () {
      createPublisher();
      sink.drain();

      hub.requestSnapshot();

      expect(sink.drain().single, isA<LiveShareSnapshot>());
    });

    test('requestSnapshot with no presenter publishes clear', () {
      hub.requestSnapshot();
      expect(sink.drain().single, isA<LiveShareClear>());
    });

    test('dispose blanks receivers with a clear', () {
      createPublisher();
      sink.drain();

      publisher!.dispose();
      publisher = null;

      expect(sink.drain().single, isA<LiveShareClear>());
      expect(hub.hasPresenter, isFalse);
    });
  });
}
