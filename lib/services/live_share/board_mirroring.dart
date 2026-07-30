import 'package:get_it/get_it.dart';
import 'package:h3xboard/services/external_display_mirror.dart';
import 'package:h3xboard/services/live_share/live_share_session_service.dart';

/// Whether the board on screen is being shown anywhere else right now — on a
/// physically attached external display, or to web viewers through a live-share
/// session.
///
/// Observable: reading it inside a MobX `Observer`/`reaction` tracks both
/// sources. Lives on its own rather than on [LiveShareHub] because the hub
/// deliberately knows nothing about its sinks' readiness — and because
/// [LiveShareSessionService] already imports the hub.
///
/// The laser pointer keys off this in two places that must not drift apart: the
/// control appears only while it is true, and the laser is put away when it
/// goes false. Without the second, unplugging the display mid-sentence would
/// leave the board armed — pointer-blocked, with its only escape a keyboard the
/// presenter may not have.
bool get isBoardMirrored =>
    GetIt.I<ExternalDisplayMirror>().isConnected || GetIt.I<LiveShareSessionService>().isSharing;
