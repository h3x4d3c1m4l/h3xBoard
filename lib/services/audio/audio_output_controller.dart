import 'dart:async';

import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/audio/audio_output_store.dart';
import 'package:h3xboard/services/live_share/live_share_hub.dart';
import 'package:mobx/mobx.dart';

part 'audio_output_controller.g.dart';

/// Where a board's widget audio comes out.
enum AudioOutput {

  /// This device's own speakers.
  thisDevice,

  /// A shared screen watching the live-share session — the classroom TV, whose
  /// speakers are the reason this setting exists.
  sharedScreen,

}

class AudioOutputController = AudioOutputControllerBase with _$AudioOutputController;

/// Owns the presenter's choice of where sound plays, and publishes it to
/// viewers.
///
/// App-wide and persisted per **device**, not per board. The choice describes
/// the room you are standing in. A board authored in a classroom must not try to
/// throw sound at a TV when that board is opened again at home.
///
/// Exactly one output is live at a time. That is the whole point. The same clip
/// arriving out of an iPad and a TV a few hundred milliseconds apart is worse
/// than either alone.
abstract class AudioOutputControllerBase with Store {

  /// Read as closures rather than taking [LiveShareSessionService] directly.
  /// They are the only two facts needed, and they keep this store testable
  /// without standing up a whole session. Because they read MobX observables,
  /// [effectiveOutput] still recomputes when either changes.
  final bool Function() _isSharing;
  final int Function() _viewerCount;

  final LiveShareHub _hub;
  final AudioOutputStore _store;

  AudioOutputControllerBase({
    required this._isSharing,
    required this._viewerCount,
    required this._hub,
    AudioOutputStore? store,
  }) : _store = store ?? AudioOutputStore();

  /// What the user asked for. Whether it is actually in force is
  /// [effectiveOutput] — the two differ when nothing is listening.
  @readonly
  AudioOutput _preferred = AudioOutput.thisDevice;

  /// Restores the stored preference. Safe to call more than once.
  Future<void> load() async {
    final stored = await _store.getOutput();
    if (stored != null) _setPreferred(stored);
  }

  @action
  void _setPreferred(AudioOutput value) => _preferred = value;

  Future<void> setPreferred(AudioOutput value) async {
    if (_preferred == value) return;
    _setPreferred(value);
    publish();
    await _store.setOutput(value);
  }

  /// Whether a shared screen could be playing at all.
  ///
  /// Two of the three ways "routed to a screen but nothing is playing there"
  /// happens are visible from here: not sharing, and sharing with nobody
  /// watching. The third is viewers connected but none with its sound switch on.
  /// That one is **not knowable**: the relay is one-way, and a viewer never
  /// sends anything back. The gap is real and deliberate.
  bool get _hasCandidateScreen => _isSharing() && _viewerCount() > 0;

  /// Where sound will actually come out right now.
  ///
  /// Falls back to this device rather than going silent when no screen could be
  /// listening. Losing a sound mid-lesson with no explanation is worse than
  /// hearing it from the wrong speaker, and the UI says which is happening.
  @computed
  AudioOutput get effectiveOutput =>
      _preferred == AudioOutput.sharedScreen && _hasCandidateScreen ? AudioOutput.sharedScreen : AudioOutput.thisDevice;

  /// True when the user asked for the shared screen but nothing can receive it.
  /// The flag lets the UI explain why sound is coming out of this device
  /// instead.
  @computed
  bool get isFallingBackToThisDevice =>
      _preferred == AudioOutput.sharedScreen && effectiveOutput == AudioOutput.thisDevice;

  /// Whether this device should make the noise.
  @computed
  bool get playsHere => effectiveOutput == AudioOutput.thisDevice;

  /// Announces the current routing to every mirror.
  ///
  /// Sends the **preference**, not [effectiveOutput]. The fallback exists so the
  /// presenter isn't left in silence, and a viewer that does have its sound on
  /// should still play. Publishing the fallback instead would mean a single
  /// viewer arriving a moment late silenced the whole session.
  void publish() => _hub.publish(LiveShareMessage.audioOutput(toViewers: _preferred == AudioOutput.sharedScreen));

  /// What a snapshot carries, so a screen joining mid-session is correct without
  /// waiting for the next toggle.
  bool get toViewers => _preferred == AudioOutput.sharedScreen;

}
