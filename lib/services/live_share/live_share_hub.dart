import 'package:flutter/foundation.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';

/// A transport for live-share messages: the local external display (plugin
/// bus) or the backend relay (web viewers). Sinks receive every published
/// message and forward it however their transport requires — including
/// dropping it when nothing is connected.
abstract class LiveShareSink {

  void send(LiveShareMessage message);

}

/// Fans live-share messages from the presenting board screen out to every
/// registered [LiveShareSink] — one protocol, N transports.
///
/// App-wide singleton: sinks are registered once at launch, while a presenter
/// (the board screen's publisher) comes and goes with the screen. Sinks whose
/// receiver (re)appears mid-session — a display plugged in, a viewer joining
/// — call [requestSnapshot] to get the full current state pushed.
class LiveShareHub {

  final List<LiveShareSink> _sinks = [];

  VoidCallback? _presenterSnapshotRequested;

  void addSink(LiveShareSink sink) => _sinks.add(sink);

  void removeSink(LiveShareSink sink) => _sinks.remove(sink);

  /// Whether a board screen is currently presenting.
  bool get hasPresenter => _presenterSnapshotRequested != null;

  /// Registers the active presenter's "publish a fresh snapshot now" hook.
  /// One presenter at a time — the board screen is a single active route.
  void registerPresenter(VoidCallback publishSnapshot) => _presenterSnapshotRequested = publishSnapshot;

  /// Unregisters [publishSnapshot] if it is still the active presenter (a new
  /// screen may have registered before the old one finished disposing).
  void unregisterPresenter(VoidCallback publishSnapshot) {
    if (_presenterSnapshotRequested == publishSnapshot) _presenterSnapshotRequested = null;
  }

  void publish(LiveShareMessage message) {
    for (final sink in _sinks) {
      sink.send(message);
    }
  }

  /// Asks the presenter to publish a fresh full snapshot (a receiver just
  /// (re)connected or fell out of sync). With no presenter, publishes an
  /// unnumbered clear instead so a stale receiver returns to idle.
  void requestSnapshot() {
    final presenter = _presenterSnapshotRequested;
    if (presenter != null) {
      presenter();
    } else {
      publish(const LiveShareMessage.clear());
    }
  }

}
