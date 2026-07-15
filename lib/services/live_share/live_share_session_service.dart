import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/live_share/live_share_hub.dart';
import 'package:h3xboard/services/live_share/server_share_sink.dart';
import 'package:mobx/mobx.dart';

/// Owns the presenter side of a web live-share session: starting/stopping it,
/// keeping it alive, and reacting to what the server reports back.
///
/// App-wide singleton. A session outlives any one board screen — the
/// presenter can hop between boards (viewers see "waiting" in between) — and
/// survives a dropped connection: on reconnect the same code is resumed
/// within the server's grace window. Publishing itself happens via the
/// [ServerShareSink] this service toggles; snapshot requests and viewer
/// counts arrive as JSON-RPC notifications on the main API connection.
class LiveShareSessionService {

  static const Duration _heartbeatInterval = Duration(seconds: 30);

  final H3xBoardApiClient _api;
  final LiveShareHub _hub;
  final ServerShareSink _sink;

  // The active session's code; null = not sharing. Observable so the share
  // dialog and the top-bar badge track it live.
  final Observable<String?> _code = Observable(null);
  final Observable<int> _viewerCount = Observable(0);

  Timer? _heartbeatTimer;
  bool _resuming = false;

  LiveShareSessionService({
    required this._api,
    required this._hub,
    required this._sink,
  }) {
    _sink.onPublishError = _onPublishError;
    _api
      ..setNotificationHandler('sharing.v1.viewerCount', _onViewerCount)
      ..setNotificationHandler('sharing.v1.snapshotRequested', (_) => _hub.requestSnapshot())
      ..setNotificationHandler('sharing.v1.ended', (_) => _cleanUp())
      // Resume the session when the connection comes back within the grace
      // window; the server re-binds the code to this new connection.
      ..connectionState.addListener(_onConnectionStateChanged);
  }

  /// The active session's viewer code, or null when not sharing. Observable.
  String? get code => _code.value;

  /// How many viewers are currently watching. Observable.
  int get viewerCount => _viewerCount.value;

  /// Whether a share session is currently live. Observable.
  bool get isSharing => _code.value != null;

  /// Starts a session (no-op when one is already live) and pushes a full
  /// snapshot so viewers joining immediately see the current board.
  Future<void> startSharing() async {
    if (isSharing) return;
    final session = await _api.startSharing();
    runInAction(() {
      _code.value = session.code;
      _viewerCount.value = session.viewerCount;
    });
    _sink.active = true;
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => unawaited(_heartbeat()));
    _hub.requestSnapshot();
  }

  /// Ends the session for every viewer.
  Future<void> stopSharing() async {
    if (!isSharing) return;
    _cleanUp();
    try {
      await _api.stopSharing();
    } catch (_) {
      // Already disconnected — the server ends the session when the grace
      // window (TTL) runs out; viewers see paused → ended.
    }
  }

  Future<void> _heartbeat() async {
    if (!isSharing) return;
    try {
      await _api.shareHeartbeat();
    } catch (_) {
      // Transient; the reconnect/resume path (or TTL expiry) settles it.
    }
  }

  void _onViewerCount(Map<String, dynamic> params) {
    final count = params['count'];
    if (count is! int) return;
    runInAction(() => _viewerCount.value = count);
  }

  void _onConnectionStateChanged() {
    if (_api.connectionState.value != H3xConnectionState.connected) return;
    final resumeCode = _code.value;
    if (resumeCode == null || _resuming) return;
    unawaited(_resume(resumeCode));
  }

  Future<void> _resume(String resumeCode) async {
    _resuming = true;
    try {
      final session = await _api.startSharing(resumeCode: resumeCode);
      runInAction(() {
        _code.value = session.code;
        _viewerCount.value = session.viewerCount;
      });
      // Viewers were paused while we were gone; bring them current again.
      _hub.requestSnapshot();
    } catch (_) {
      // The grace window expired (or the code was rejected) — the session is
      // gone; reflect that instead of silently sharing into the void.
      _cleanUp();
    } finally {
      _resuming = false;
    }
  }

  void _onPublishError(Object error) {
    // A dropped connection pauses the session (resume handles it); any other
    // publish failure is healed by the next snapshot. Nothing to do here
    // beyond not spamming — the sink already dropped its queue.
    debugPrint('Live-share publish failed: $error');
  }

  void _cleanUp() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _sink.active = false;
    runInAction(() {
      _code.value = null;
      _viewerCount.value = 0;
    });
  }

}
