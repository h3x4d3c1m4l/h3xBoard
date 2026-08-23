import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/board_asset_resolver.dart';
import 'package:h3xboard/services/live_share/live_share_hub.dart';
import 'package:h3xboard/services/live_share/live_view_client.dart';

/// Puts the board this device is *watching* on the screens attached to it: the
/// presenter half of the protocol for a device that isn't presenting anything
/// of its own.
///
/// Watching a shared board on a tablet with a TV hooked up should light up both
/// screens, but the external display only ever draws what a presenter puts on
/// the [LiveShareHub] — and a viewer screen registers none. This takes that
/// role and republishes every frame arriving from the viewer's transport
/// verbatim, so the display renders a relayed board exactly as it renders an
/// edited one.
///
/// Two things follow from the board belonging to someone else:
///
/// - **It is relayed to [LiveShareAudience.thisDevice] only.** This user's own
///   share session outlives the board screen, so an unscoped publish would put
///   a board they never presented under their own code.
/// - **Frames keep the original presenter's sequence numbers**, which start
///   mid-stream from this hub's point of view. A display plugged in later lands
///   in the middle of that sequence and its receiver freezes on the gap;
///   [publishRetainedSnapshot] answers with the last snapshot seen — a snapshot
///   resets the receiver's baseline — and asks the presenter for a fresh one,
///   since everything after that snapshot is already past.
class LiveViewRelay {

  final LiveShareHub _hub;
  final Stream<LiveShareMessage> _messages;
  final ValueListenable<LiveViewState> _state;

  /// Asks the presenter (through the server) for a fresh snapshot. Rate-limited
  /// by the caller — see [LiveViewClient.requestResync].
  final VoidCallback _requestResync;

  late final LiveSharePresenter _presenter;
  StreamSubscription<LiveShareMessage>? _subscription;

  // The last full frame seen, i.e. the only thing this relay can answer a
  // snapshot request with. Deltas since then are already on the wire.
  LiveShareSnapshot? _lastSnapshot;

  LiveViewRelay({
    required this._hub,
    required this._messages,
    required this._state,
    required this._requestResync,
    required BoardAssetResolver assets,
  }) {
    _presenter = LiveSharePresenter(publishSnapshot: publishRetainedSnapshot, assets: assets);
    _hub.registerPresenter(_presenter);
    _subscription = _messages.listen(_onMessage);
    _state.addListener(_onStateChanged);
  }

  void _onMessage(LiveShareMessage message) {
    if (message is LiveShareSnapshot) _lastSnapshot = message;
    _relay(message);
  }

  /// A session that has stopped for good takes the attached screens back to
  /// idle. The viewer itself says why over its own copy of the board; the
  /// display has no such panel, and leaving a dead board up there is worse than
  /// leaving nothing.
  void _onStateChanged() {
    switch (_state.value) {
      case LiveViewState.ended || LiveViewState.notFound || LiveViewState.full:
        _lastSnapshot = null;
        _relay(const LiveShareMessage.clear());
      case _:
        break;
    }
  }

  /// Re-sends the last snapshot to the attached screens and asks for a fresh
  /// one. Registered as the presenter's snapshot hook, so it runs whenever a
  /// display connects or a receiver reports a gap.
  void publishRetainedSnapshot() {
    final snapshot = _lastSnapshot;
    _relay(snapshot ?? const LiveShareMessage.clear());
    _requestResync();
  }

  void _relay(LiveShareMessage message) => _hub.publish(message, audience: LiveShareAudience.thisDevice);

  /// Stops relaying and blanks the attached screens back to idle.
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _state.removeListener(_onStateChanged);
    _hub.unregisterPresenter(_presenter);
    _relay(const LiveShareMessage.clear());
  }

}
