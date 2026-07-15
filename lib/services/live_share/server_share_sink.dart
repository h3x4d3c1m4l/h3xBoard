import 'dart:async';

import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/live_share/live_share_hub.dart';

/// Relays live-share messages to the backend (`sharing.v1.publish`) for web
/// viewers, while a share session is [active].
///
/// Messages are sent in order and none are dropped — receivers detect loss by
/// sequence gap, so thinning would read as data loss. Instead, traffic is
/// shaped by batching: messages accumulate for up to [_flushInterval] and go
/// out as one RPC (~20 sends/s during drawing instead of one per frame).
/// Snapshots flush immediately so joins and resyncs stay snappy.
class ServerShareSink implements LiveShareSink {

  static const Duration _flushInterval = Duration(milliseconds: 50);

  final H3xBoardApiClient _api;

  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;
  bool _sending = false;
  bool _active = false;

  /// Fired when a publish batch fails (connection drop, session rejected).
  /// The queued batch is dropped — the session service reacts by resuming or
  /// ending the session, and a fresh snapshot heals viewers either way.
  void Function(Object error)? onPublishError;

  ServerShareSink({required this._api});

  /// Whether a share session is live. While false every message is dropped
  /// (the sink stays registered on the hub permanently).
  bool get active => _active;

  set active(bool value) {
    _active = value;
    if (!value) {
      _flushTimer?.cancel();
      _flushTimer = null;
      _queue.clear();
    }
  }

  @override
  void send(LiveShareMessage message) {
    if (!_active) return;
    _queue.add(message.toJson());
    if (message is LiveShareSnapshot) {
      _flush();
    } else {
      _flushTimer ??= Timer(_flushInterval, _flush);
    }
  }

  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_queue.isEmpty || _sending) return;
    final batch = List.of(_queue);
    _queue.clear();
    _sending = true;
    unawaited(_api.publishShare(batch).then(
      (_) {
        _sending = false;
        // More arrived while this batch was in flight — keep draining.
        if (_queue.isNotEmpty) _flush();
      },
      onError: (Object error) {
        _sending = false;
        _queue.clear();
        onPublishError?.call(error);
      },
    ));
  }

}
