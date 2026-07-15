import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
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
/// via its surface painter, both coalesced to at most one publish per frame.
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
  final bool Function() _isLoading;

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

  // Coalesces the flurry of drawing notifications during a stroke into at
  // most one publish per frame.
  bool _frameScheduled = false;
  bool _committedDirty = false;
  bool _surfaceDirty = false;

  LiveBoardPublisher({
    required this._hub,
    required this._drawingController,
    required this._board,
    required this._widgets,
    required this._isLoading,
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

  // Drawing deltas (DrawingController notifiers, coalesced per frame)

  void _onDrawingCommitted() {
    _committedDirty = true;
    _scheduleDrawingFrame();
  }

  void _onSurfaceRepaint() {
    _surfaceDirty = true;
    _scheduleDrawingFrame();
  }

  void _scheduleDrawingFrame() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _frameScheduled = false;
        _onDrawingFrame();
      })
      // Guarantee that next frame exists: a notification landing while the
      // scheduler is idle would otherwise wait for an unrelated repaint.
      ..ensureVisualUpdate();
  }

  void _onDrawingFrame() {
    final committedDirty = _committedDirty;
    final surfaceDirty = _surfaceDirty;
    _committedDirty = false;
    _surfaceDirty = false;
    if (!_publishedAnything) return;

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

    _publishedAnything = true;
    _lastBoard = board;
    _lastWidgets = widgets;
    _lastStrokes = strokes;
    _lastFileIds = fileIds;
    _hadInProgress = inProgress != null;
    _deltasSinceSnapshot = 0;

    _hub.publish(LiveShareMessage.snapshot(
      seq: _nextSeq(),
      board: board,
      widgets: widgets,
      strokes: [for (final s in strokes) s.toJson()],
      inProgress: inProgress?.toJson(),
      fileIds: fileIds.toList(),
    ));
  }

  void _publishDelta(LiveShareMessage message) {
    _hub.publish(message);
    if (++_deltasSinceSnapshot >= _safetySnapshotEvery) publishSnapshot();
  }

  /// Every uploaded file the given state references — the image widgets'
  /// files plus the board's background image.
  Set<String> _fileIdsOf(Board board, List<BoardWidget> widgets) => {
        for (final w in widgets)
          if (w.config case ImageConfig(:final fileId) when fileId.isNotEmpty) fileId,
        if (board.backgroundFileId != null) board.backgroundFileId!,
      };

  /// Stops observing and blanks all receivers back to idle.
  void dispose() {
    _safetyTimer?.cancel();
    _stateReactionDisposer();
    _drawingController
      ..removeListener(_onDrawingCommitted)
      ..painter?.removeListener(_onSurfaceRepaint);
    _hub
      ..unregisterPresenter(publishSnapshot)
      ..publish(LiveShareMessage.clear(seq: _nextSeq()));
  }

}
