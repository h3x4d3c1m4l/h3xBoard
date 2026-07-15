import 'package:flutter/foundation.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/drawing_serialization.dart';

/// Rebuilds a mirrored board from a stream of [LiveShareMessage]s — the
/// receive half of the live-share protocol, shared by the external-display
/// isolate and the web viewer.
///
/// State is split across three notifiers so each change repaints only what it
/// must: board/widget changes notify this [ChangeNotifier] (the hosting view
/// rebuilds), committed strokes land in [drawingController] (the DrawingBoard
/// repaints itself), and the in-progress stroke lives in [inProgress] (a
/// dedicated overlay repaints per frame). During a stroke nothing but the
/// overlay repaints.
///
/// Presenter messages carry a per-session sequence number. On a lossy
/// transport a gap means deltas can no longer be applied safely; the receiver
/// then freezes (skips deltas), fires [onGapDetected] once so the transport
/// can request a resync, and resumes at the next snapshot — a snapshot always
/// fully replaces state and resets the baseline.
class LiveBoardReceiver extends ChangeNotifier {

  final DrawingController drawingController = DrawingController();

  /// The presenter's not-yet-committed stroke, drawn on an overlay above the
  /// committed drawing. null = no stroke in progress.
  final ValueNotifier<PaintContent?> inProgress = ValueNotifier<PaintContent?>(null);

  Board? _board;
  List<BoardWidget> _widgets = const [];

  int _lastSeq = 0;
  bool _needsResync = false;

  /// Fired once per gap, until the next snapshot heals it.
  VoidCallback? onGapDetected;

  /// The mirrored sub-board; null = idle (nothing being presented).
  Board? get board => _board;

  /// The mirrored widgets, in render order.
  List<BoardWidget> get widgets => _widgets;

  /// Whether a sequence gap is waiting to be healed by the next snapshot.
  bool get needsResync => _needsResync;

  void apply(LiveShareMessage message) {
    switch (message) {
      case LiveShareSnapshot m:
        _applySnapshot(m);
      case LiveShareBoardProps m:
        if (_acceptDelta(m.seq)) {
          _board = m.board;
          notifyListeners();
        }
      case LiveShareWidgetUpserted m:
        if (_acceptDelta(m.seq)) {
          _upsertWidget(m.widget);
          notifyListeners();
        }
      case LiveShareWidgetsSet m:
        if (_acceptDelta(m.seq)) {
          _widgets = m.widgets;
          notifyListeners();
        }
      case LiveShareStrokeProgress m:
        if (_acceptDelta(m.seq)) {
          final stroke = m.stroke;
          inProgress.value = stroke == null ? null : _restoreStroke(stroke);
        }
      case LiveShareStrokeCommitted m:
        if (_acceptDelta(m.seq)) {
          final stroke = _restoreStroke(m.stroke);
          if (stroke != null) drawingController.addContents([stroke]);
          inProgress.value = null;
        }
      case LiveShareDrawingSet m:
        if (_acceptDelta(m.seq)) {
          drawingController.clear();
          final strokes = restoreDrawingContents(m.strokes);
          if (strokes.isNotEmpty) drawingController.addContents(strokes);
        }
      case LiveShareClear m:
        if (_acceptDelta(m.seq)) _applyIdle();
      // Transport-level frames (hello, session lifecycle, viewer count) are
      // handled by the transport client; frame types from a newer peer are
      // skipped — the next snapshot re-syncs whatever they would have changed.
      default:
        break;
    }
  }

  void _applySnapshot(LiveShareSnapshot m) {
    _lastSeq = m.seq;
    _needsResync = false;
    _board = m.board;
    _widgets = m.widgets;
    drawingController.clear();
    final strokes = restoreDrawingContents(m.strokes);
    if (strokes.isNotEmpty) drawingController.addContents(strokes);
    final inProgressJson = m.inProgress;
    inProgress.value = inProgressJson == null ? null : _restoreStroke(inProgressJson);
    notifyListeners();
  }

  void _applyIdle() {
    _board = null;
    _widgets = const [];
    drawingController.clear();
    inProgress.value = null;
    notifyListeners();
  }

  /// Tracks the presenter sequence and decides whether a delta may be
  /// applied. Frames with `seq <= 0` (server-origin, or a peer that doesn't
  /// number frames) bypass gap tracking — their transport guarantees order.
  bool _acceptDelta(int seq) {
    if (seq <= 0) return true;
    if (_needsResync) {
      // Already frozen; keep following the sequence so recovery stays cheap.
      _lastSeq = seq;
      return false;
    }
    if (_lastSeq == 0 || seq != _lastSeq + 1) {
      // A delta with no baseline (joined mid-session before any snapshot) or
      // with missed predecessors — state would corrupt, freeze until the next
      // snapshot instead.
      _lastSeq = seq;
      _needsResync = true;
      onGapDetected?.call();
      return false;
    }
    _lastSeq = seq;
    return true;
  }

  void _upsertWidget(BoardWidget widget) {
    final index = _widgets.indexWhere((w) => w.id == widget.id);
    // Replace in place to preserve render order; append when new.
    _widgets = [
      for (var i = 0; i < _widgets.length; i++) i == index ? widget : _widgets[i],
      if (index == -1) widget,
    ];
  }

  PaintContent? _restoreStroke(Map<String, dynamic> json) =>
      restoreDrawingContents([json]).firstOrNull;

  @override
  void dispose() {
    inProgress.dispose();
    drawingController.dispose();
    super.dispose();
  }

}
