import 'package:flutter/foundation.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/board_asset_resolver.dart';

/// Which mirrors a message is meant for.
enum LiveShareAudience {

  /// Every sink: the screens attached to this device and web viewers.
  everywhere,

  /// Only the screens attached to this device.
  ///
  /// What a relayed board uses. Its content belongs to another presenter, so
  /// putting it on this device's own share code would show that session's
  /// viewers a board its user never presented.
  thisDevice,

}

/// A transport for live-share messages: the local external display (plugin
/// bus) or the backend relay (web viewers). Sinks receive every published
/// message and forward it however their transport requires — including
/// dropping it when nothing is connected.
abstract class LiveShareSink {

  /// Whether this sink drives a screen attached to this device. Messages sent
  /// to [LiveShareAudience.thisDevice] reach only these sinks.
  bool get isDeviceLocal;

  void send(LiveShareMessage message);

}

/// Whoever is currently feeding the hub: the board screen being edited, or a
/// viewer screen relaying someone else's board (see `LiveViewRelay`).
class LiveSharePresenter {

  /// Publishes the presenter's full current state to the hub.
  final VoidCallback publishSnapshot;

  /// Where the bytes of the files the presented board references come from.
  ///
  /// Travels with the presenter because it is the only thing that knows: an
  /// edited board's files come from the signed-in user's authenticated file
  /// service, a relayed board's from the anonymous share-code endpoint, and no
  /// sink can tell those apart from a snapshot.
  final BoardAssetResolver assets;

  const LiveSharePresenter({required this.publishSnapshot, required this.assets});

}

/// Fans live-share messages from the presenting screen out to every registered
/// [LiveShareSink] — one protocol, N transports.
///
/// App-wide singleton: sinks are registered once at launch, while a presenter
/// comes and goes with the screen. Sinks whose receiver (re)appears
/// mid-session — a display plugged in, a viewer joining — call
/// [requestSnapshot] to get the full current state pushed.
class LiveShareHub {

  final List<LiveShareSink> _sinks = [];

  LiveSharePresenter? _presenter;

  void addSink(LiveShareSink sink) => _sinks.add(sink);

  void removeSink(LiveShareSink sink) => _sinks.remove(sink);

  /// Whether a screen is currently presenting.
  bool get hasPresenter => _presenter != null;

  /// The active presenter's file-byte source, or null when nobody presents.
  BoardAssetResolver? get presenterAssets => _presenter?.assets;

  /// Registers the active presenter. One at a time — presenting screens are a
  /// single active route.
  void registerPresenter(LiveSharePresenter presenter) => _presenter = presenter;

  /// Unregisters [presenter] if it is still the active one (a new screen may
  /// have registered before the old one finished disposing).
  void unregisterPresenter(LiveSharePresenter presenter) {
    if (_presenter == presenter) _presenter = null;
  }

  void publish(LiveShareMessage message, {LiveShareAudience audience = LiveShareAudience.everywhere}) {
    for (final sink in _sinks) {
      if (audience == LiveShareAudience.thisDevice && !sink.isDeviceLocal) continue;
      sink.send(message);
    }
  }

  /// Asks the presenter to publish a fresh full snapshot (a receiver just
  /// (re)connected or fell out of sync). With no presenter, publishes an
  /// unnumbered clear instead so a stale receiver returns to idle.
  void requestSnapshot() {
    final presenter = _presenter;
    if (presenter != null) {
      presenter.publishSnapshot();
    } else {
      publish(const LiveShareMessage.clear());
    }
  }

}
