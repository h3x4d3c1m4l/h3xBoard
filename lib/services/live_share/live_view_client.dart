import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:h3xboard/services/websocket/websocket_connect_web.dart'
    if (dart.library.io) 'package:h3xboard/services/websocket/websocket_connect_io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// What the viewer screen should show for a [LiveViewClient].
enum LiveViewState {

  /// Opening the socket (first connect).
  connecting,

  /// Connected; the presenter is live and frames are flowing.
  live,

  /// Connected, but nothing is being presented right now.
  waiting,

  /// The presenter's connection dropped; the session may resume.
  paused,

  /// The connection dropped on our side; retrying in the background.
  reconnecting,

  /// Terminal: the presenter stopped sharing or the session expired.
  ended,

  /// Terminal: the code doesn't (or no longer) match a session.
  notFound,

  /// Terminal: the session is at its viewer cap.
  full,

}

/// The web viewer's transport: an anonymous WebSocket to the backend's
/// `/ws/v1/view/{code}` endpoint. No login, no JSON-RPC — the server streams
/// [LiveShareMessage] frames (hello → cached snapshot → live deltas) which
/// this client splits into [state] (session lifecycle) and [messages] (board
/// content for `LiveBoardView`).
///
/// Stays alive through connection drops: reconnects with backoff and the
/// server replays a fresh hello + snapshot, so no client-side state is
/// needed. Sends a presence ping every [_pingInterval] (that's what the
/// presenter's viewer count counts) and rate-limited resync requests when the
/// receiver reports a sequence gap.
class LiveViewClient {

  static const Duration _pingInterval = Duration(seconds: 15);
  static const Duration _resyncCooldown = Duration(seconds: 5);

  final String serverUrl;
  final String code;

  final StreamController<LiveShareMessage> _messages = StreamController.broadcast();
  final ValueNotifier<LiveViewState> state = ValueNotifier(LiveViewState.connecting);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  DateTime? _lastResyncRequest;
  bool _disposed = false;
  bool _reconnecting = false;

  LiveViewClient({required this.serverUrl, required this.code});

  /// Board-content frames, for a `LiveBoardView`.
  Stream<LiveShareMessage> get messages => _messages.stream;

  bool get _isTerminal =>
      state.value == LiveViewState.ended ||
      state.value == LiveViewState.notFound ||
      state.value == LiveViewState.full;

  /// Opens the socket; a failed first handshake (server briefly unreachable,
  /// or a server that predates live sharing) enters the same background retry
  /// loop as a dropped connection instead of throwing.
  Future<void> start() async {
    try {
      await _connect();
    } catch (_) {
      _onConnectionLost();
    }
  }

  Future<void> _connect() async {
    final wsUrl = serverUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsUrl/ws/v1/view/$code');
    // The endpoint is anonymous; the shared connect helper just also carries
    // cookies on IO, which the server ignores here.
    final channel = await connectWebSocket(uri, CookieStore());
    _channel = channel;
    _subscription = channel.stream.listen(_onFrame, onError: (Object _) => _onConnectionLost(), onDone: _onConnectionLost);
    _pingTimer = Timer.periodic(_pingInterval, (_) => _send(const LiveShareMessage.ping()));
  }

  void _onFrame(dynamic raw) {
    final LiveShareMessage message;
    try {
      message = LiveShareMessage.fromJson(jsonDecode(raw as String) as Map<String, dynamic>);
    } catch (_) {
      // A malformed frame is dropped; the next snapshot re-syncs everything.
      return;
    }
    switch (message) {
      case LiveShareHello m:
        state.value = switch (m.state) {
          LiveShareViewerState.live => LiveViewState.live,
          LiveShareViewerState.waiting => LiveViewState.waiting,
          LiveShareViewerState.notFound => LiveViewState.notFound,
          LiveShareViewerState.full => LiveViewState.full,
        };
        if (_isTerminal) _shutDown();
      case LiveShareSessionPaused _:
        state.value = LiveViewState.paused;
      case LiveShareSessionResumed _:
        state.value = LiveViewState.live;
      case LiveShareSessionEnded _:
        state.value = LiveViewState.ended;
        _shutDown();
      case LiveShareViewerCount _:
        // Viewer counts are presenter-facing; viewers don't show them.
        break;
      case LiveShareSnapshot _:
        state.value = LiveViewState.live;
        _messages.add(message);
      case LiveShareClear _:
        state.value = LiveViewState.waiting;
        _messages.add(message);
      default:
        _messages.add(message);
    }
  }

  /// Asks the presenter (via the server) for a fresh snapshot after the
  /// receiver detected a sequence gap. Rate-limited — the safety-snapshot
  /// cadence covers a lost request.
  void requestResync() {
    final now = DateTime.now();
    final last = _lastResyncRequest;
    if (last != null && now.difference(last) < _resyncCooldown) return;
    _lastResyncRequest = now;
    _send(const LiveShareMessage.resyncRequest());
  }

  void _send(LiveShareMessage message) {
    try {
      _channel?.sink.add(jsonEncode(message.toJson()));
    } catch (_) {
      // A failed ping/resync is retried by its own cadence.
    }
  }

  void _onConnectionLost() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _channel = null;
    if (_disposed || _isTerminal || _reconnecting) return;
    state.value = LiveViewState.reconnecting;
    unawaited(_reconnect());
  }

  /// Retries with exponential backoff (capped at 15s) until the socket is
  /// back or the client is disposed. On success the server sends a fresh
  /// hello + snapshot, which resets [state] and the receiver's content.
  Future<void> _reconnect() async {
    _reconnecting = true;
    var attempt = 0;
    try {
      while (!_disposed && _channel == null) {
        try {
          await _connect();
          return;
        } catch (_) {
          final seconds = 1 << attempt++;
          await Future<void>.delayed(Duration(seconds: seconds > 15 ? 15 : seconds));
        }
      }
    } finally {
      _reconnecting = false;
    }
  }

  void _shutDown() {
    _pingTimer?.cancel();
    _pingTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_channel?.sink.close());
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    _shutDown();
    unawaited(_messages.close());
    state.dispose();
  }

}
