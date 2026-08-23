import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/laser_pointer.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/live_share/live_share_hub.dart';
import 'package:mobx/mobx.dart';

/// The send half of the live-share protocol: watches the board screen's state
/// and turns changes into [LiveShareMessage]s on the [LiveShareHub] — a full
/// snapshot when the shown board changes (or a receiver asks for one), small
/// deltas for everything else.
///
/// State is observed, not instrumented: a MobX `autorun` over the injected
/// getters catches every board/widget mutation — including undo/redo closures
/// that bypass the controller's handlers — and the publisher diffs against
/// what it last published to pick the smallest message. The drawing canvas
/// isn't MobX: committed-stroke changes arrive via the [DrawingController]'s
/// own notifier (stroke end, undo/redo/clear rebuilds) and mid-stroke motion
/// via its surface painter. The laser pointer is a notifier too, for the same
/// reason — it moves every frame. All three are coalesced to at most one
/// publish per frame.
///
/// Every message carries a session-monotonic [seq] so lossy transports can
/// detect gaps. Safety snapshots (every [_safetySnapshotEvery] deltas, or
/// [_safetySnapshotInterval] with deltas pending) bound how long a gap can
/// last even if a resync request goes missing.
class LiveBoardPublisher {

  static const int _safetySnapshotEvery = 500;
  static const Duration _safetySnapshotInterval = Duration(seconds: 30);

  final LiveShareHub _hub;
  final DrawingController _drawingController;
  final Board Function() _board;
  final List<BoardWidget> Function() _widgets;
  final String? Function() _fullScreenWidgetId;
  final bool Function() _isLoading;
  final ValueListenable<LaserPointer?> _laser;

  /// Where the presenter has routed audio, read at snapshot time so a screen
  /// joining mid-session is correct without waiting for the next toggle.
  /// Changes to it publish their own delta (see [AudioOutputController]).
  final bool Function() _audioToViewers;

  late final ReactionDisposer _stateReactionDisposer;
  Timer? _safetyTimer;

  int _seq = 0;
  int _deltasSinceSnapshot = 0;

  // What receivers currently show, i.e. the last published state. Strokes are
  // compared by identity: the editor only ever appends a finished stroke or
  // rebuilds the list wholesale (undo/redo/clear), so identity tells an
  // append apart from a rebuild for free.
  bool _publishedAnything = false;
  Board? _lastBoard;
  List<BoardWidget> _lastWidgets = const [];
  List<PaintContent> _lastStrokes = const [];
  Set<String> _lastFileIds = const {};
  bool _hadInProgress = false;
  LaserPointer? _lastLaser;
  String? _lastFullScreenWidgetId;

  // Coalesces the flurry of drawing and pointer notifications during a stroke
  // into at most one publish per frame.
  bool _frameScheduled = false;
  bool _committedDirty = false;
  bool _surfaceDirty = false;
  bool _laserDirty = false;

  LiveBoardPublisher({
    required this._hub,
    required this._drawingController,
    required this._board,
    required this._widgets,
    required this._fullScreenWidgetId,
    required this._isLoading,
    required this._laser,
    required this._audioToViewers,
  }) {
    _hub.registerPresenter(publishSnapshot);
    // Re-evaluate on any observable change: the getters read the view model's
    // board/widget observables, so autorun tracks them as dependencies.
    _stateReactionDisposer = autorun((_) => _onStateTick());
    // Committed strokes: fires on stroke end and on the clear+addContents
    // rebuilds undo/redo/clear perform.
    _drawingController.addListener(_onDrawingCommitted);
    // Live drawing: the surface painter notifies on every pointer move.
    _drawingController.painter?.addListener(_onSurfaceRepaint);
    _laser.addListener(_onLaserChanged);
    _safetyTimer = Timer.periodic(_safetySnapshotInterval, (_) {
      if (_deltasSinceSnapshot > 0) publishSnapshot();
    });
  }

  int _nextSeq() => ++_seq;

  // Board & widget deltas (MobX autorun)

  void _onStateTick() {
    if (_isLoading()) return;
    final board = _board();
    final widgets = _widgets();

    // First publish, board switch, or a change to which files are referenced
    // (the server's viewer-download allowlist is taken from snapshots, so it
    // must never go stale) — all warrant a full snapshot.
    if (!_publishedAnything || board.id != _lastBoard?.id || !setEquals(_fileIdsOf(board, widgets), _lastFileIds)) {
      publishSnapshot();
      return;
    }

    if (board != _lastBoard) {
      _lastBoard = board;
      _publishDelta(LiveShareMessage.boardProps(seq: _nextSeq(), board: board));
    }

    final widgetsDelta = _diffWidgets(_lastWidgets, widgets);
    if (widgetsDelta != null) {
      _lastWidgets = widgets;
      _publishDelta(widgetsDelta);
    }

    // After the widget deltas: entering full screen on a freshly added widget
    // must not reach receivers before the widget it names.
    final fullScreenWidgetId = _fullScreenWidgetId();
    if (fullScreenWidgetId != _lastFullScreenWidgetId) {
      _lastFullScreenWidgetId = fullScreenWidgetId;
      _publishDelta(LiveShareMessage.fullScreen(seq: _nextSeq(), widgetId: fullScreenWidgetId));
    }
  }

  /// The smallest message expressing `old → current`, or null when nothing
  /// changed. A single widget replaced in place or appended — by far the most
  /// frequent case (move, resize, config edit, stopwatch tick, add) — becomes
  /// an upsert; everything else replaces the list.
  LiveShareMessage? _diffWidgets(List<BoardWidget> old, List<BoardWidget> current) {
    if (listEquals(old, current)) return null;
    if (current.length == old.length) {
      var changedIndex = -1;
      for (var i = 0; i < current.length; i++) {
        if (old[i] == current[i]) continue;
        // A second change, or a different widget in this slot (reorder/
        // remove+add) — no single upsert expresses that.
        if (changedIndex != -1 || old[i].id != current[i].id) {
          return LiveShareMessage.widgetsSet(seq: _nextSeq(), widgets: current);
        }
        changedIndex = i;
      }
      return LiveShareMessage.widgetUpserted(seq: _nextSeq(), widget: current[changedIndex]);
    }
    if (current.length == old.length + 1) {
      for (var i = 0; i < old.length; i++) {
        if (old[i] != current[i]) {
          return LiveShareMessage.widgetsSet(seq: _nextSeq(), widgets: current);
        }
      }
      return LiveShareMessage.widgetUpserted(seq: _nextSeq(), widget: current.last);
    }
    return LiveShareMessage.widgetsSet(seq: _nextSeq(), widgets: current);
  }

  // Drawing and laser deltas (notifier-driven, coalesced per frame)

  void _onDrawingCommitted() {
    _committedDirty = true;
    _schedulePublishFrame();
  }

  void _onSurfaceRepaint() {
    _surfaceDirty = true;
    _schedulePublishFrame();
  }

  void _onLaserChanged() {
    _laserDirty = true;
    _schedulePublishFrame();
  }

  void _schedulePublishFrame() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _frameScheduled = false;
        _onPublishFrame();
      })
      // Guarantee that next frame exists: a notification landing while the
      // scheduler is idle would otherwise wait for an unrelated repaint.
      ..ensureVisualUpdate();
  }

  void _onPublishFrame() {
    final committedDirty = _committedDirty;
    final surfaceDirty = _surfaceDirty;
    final laserDirty = _laserDirty;
    _committedDirty = false;
    _surfaceDirty = false;
    _laserDirty = false;
    if (!_publishedAnything) return;

    if (laserDirty) _publishLaser();

    var committedThisFrame = false;
    if (committedDirty) {
      final strokes = _committedStrokes();
      if (_isSingleAppend(_lastStrokes, strokes)) {
        _publishDelta(LiveShareMessage.strokeCommitted(seq: _nextSeq(), stroke: strokes.last.toJson()));
        // Receivers drop their in-progress stroke on a commit — it was this one.
        _hadInProgress = false;
        committedThisFrame = true;
      } else if (!_identicalStrokes(_lastStrokes, strokes)) {
        _publishDelta(LiveShareMessage.drawingSet(seq: _nextSeq(), strokes: [for (final s in strokes) s.toJson()]));
      }
      _lastStrokes = strokes;
    }

    final inProgress = _drawingController.drawingContent ?? _drawingController.eraserContent;
    if (inProgress != null) {
      if (surfaceDirty) {
        _hadInProgress = true;
        _publishDelta(LiveShareMessage.strokeProgress(seq: _nextSeq(), stroke: inProgress.toJson()));
      }
    } else if (_hadInProgress && !committedThisFrame) {
      // The stroke vanished without a commit (gesture cancelled).
      _hadInProgress = false;
      _publishDelta(LiveShareMessage.strokeProgress(seq: _nextSeq()));
    }
  }

  /// Sends the pointer's new position (or its removal).
  ///
  /// Published straight to the hub rather than through [_publishDelta] on
  /// purpose: the laser is the highest-volume frame in the protocol, and
  /// letting it drive the safety-snapshot counter would re-send the whole board
  /// every few seconds of pointing to heal state that never changed. A lost
  /// laser frame is still caught by the receiver's sequence check, which asks
  /// for a resync — the counter is not what protects it.
  void _publishLaser() {
    final laser = _laser.value;
    if (laser == _lastLaser) return;
    _lastLaser = laser;
    _hub.publish(LiveShareMessage.laser(seq: _nextSeq(), pointer: laser));
  }

  /// The strokes receivers should show: the history up to the undo pointer.
  /// (This app rebuilds on undo/redo so the pointer stays at the end, but
  /// slicing keeps the publisher correct either way.)
  List<PaintContent> _committedStrokes() =>
      List.unmodifiable(_drawingController.getHistory.sublist(0, _drawingController.currentIndex));

  static bool _identicalStrokes(List<PaintContent> a, List<PaintContent> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  static bool _isSingleAppend(List<PaintContent> old, List<PaintContent> current) {
    if (current.length != old.length + 1) return false;
    for (var i = 0; i < old.length; i++) {
      if (!identical(old[i], current[i])) return false;
    }
    return true;
  }

  // Snapshots

  /// Publishes the full current state. Called on board switches and first
  /// publish, when a receiver (re)connects or requests a resync, when the
  /// referenced-file set changes, and on the safety cadence.
  void publishSnapshot() {
    if (_isLoading()) return;
    final board = _board();
    final widgets = _widgets();
    final strokes = _committedStrokes();
    final inProgress = _drawingController.drawingContent ?? _drawingController.eraserContent;
    final fileIds = _fileIdsOf(board, widgets);
    final fullScreenWidgetId = _fullScreenWidgetId();

    _publishedAnything = true;
    _lastBoard = board;
    _lastWidgets = widgets;
    _lastStrokes = strokes;
    _lastFileIds = fileIds;
    _hadInProgress = inProgress != null;
    _lastLaser = _laser.value;
    _lastFullScreenWidgetId = fullScreenWidgetId;
    _deltasSinceSnapshot = 0;

    _hub.publish(LiveShareMessage.snapshot(
      seq: _nextSeq(),
      board: board,
      widgets: widgets,
      strokes: [for (final s in strokes) s.toJson()],
      inProgress: inProgress?.toJson(),
      fileIds: fileIds.toList(),
      // Carried so a viewer joining mid-sentence sees the dot straight away
      // rather than staying blind until the presenter next moves it.
      laser: _laser.value,
      fullScreenWidgetId: fullScreenWidgetId,
      audioToViewers: _audioToViewers(),
    ));
  }

  void _publishDelta(LiveShareMessage message) {
    _hub.publish(message);
    if (++_deltasSinceSnapshot >= _safetySnapshotEvery) publishSnapshot();
  }

  /// Every uploaded file the given state references — the image widgets', sound
  /// pads' and audio players' files plus the board's background image.
  ///
  /// This set is the server's allowlist for anonymous viewer downloads, so a
  /// widget missing from here shows a viewer a 404 rather than its content.
  Set<String> _fileIdsOf(Board board, List<BoardWidget> widgets) => {
        for (final w in widgets)
          if (w.config case ImageConfig(:final fileId) when fileId.isNotEmpty) fileId,
        for (final w in widgets)
          if (w.config case SoundPadConfig(:final fileId) when fileId.isNotEmpty) fileId,
        for (final w in widgets)
          if (w.config case AudioPlayerConfig(:final fileId) when fileId.isNotEmpty) fileId,
        if (board.backgroundFileId != null) board.backgroundFileId!,
      };

  /// Stops observing and blanks all receivers back to idle.
  void dispose() {
    _safetyTimer?.cancel();
    _stateReactionDisposer();
    _drawingController
      ..removeListener(_onDrawingCommitted)
      ..painter?.removeListener(_onSurfaceRepaint);
    _laser.removeListener(_onLaserChanged);
    _hub
      ..unregisterPresenter(publishSnapshot)
      ..publish(LiveShareMessage.clear(seq: _nextSeq()));
  }

}
