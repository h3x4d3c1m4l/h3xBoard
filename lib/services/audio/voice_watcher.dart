import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Notices when a single previewed voice ends on its own.
///
/// A play/stop button has no other way to find out. SoLoud tells nobody when a
/// voice runs to its end, so without this the button stays on "stop" for a sound
/// that finished seconds ago, and pressing it stops nothing.
///
/// **Polling rather than SoLoud's `allInstancesFinished`**, which fires per audio
/// *source*. A source is shared by every widget previewing the same file, so that
/// stream would hold one preview's button open until every other copy went quiet
/// too. A handle belongs to one widget alone.
///
/// The timer only exists while a voice is live, so an idle preview costs nothing.
/// [dispose] MUST be called from the owner's `dispose`.
class VoiceWatcher {

  /// Frequent enough that the button never looks stuck, cheap enough that it
  /// does not matter — it is one validity check against an integer handle.
  static const Duration _interval = Duration(milliseconds: 200);

  Timer? _timer;

  /// Calls [onEnded] once [handle] is no longer sounding. Replaces whatever was
  /// being watched before, so a caller may start a new preview without cancelling
  /// the old watch first.
  void watch(SoundHandle handle, VoidCallback onEnded) {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (SoLoud.instance.getIsValidVoiceHandle(handle)) return;
      cancel();
      onEnded();
    });
  }

  /// Stops watching without calling back — for a voice the user stopped, whose
  /// owner has already updated itself.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();

}
