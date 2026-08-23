import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/services/audio/audio_output_controller.dart';

/// Whether the surface a board widget is drawn on is allowed to make noise.
///
/// Three surfaces render the same widgets, and only one of them should sound at
/// a time. So the answer cannot live in the widget: it belongs to the surface.
abstract class BoardAudioPolicy {

  const BoardAudioPolicy();

  /// Whether audio triggered on this surface should actually be played here.
  bool get playsHere;

  /// Whether this subtree is a second live copy of a widget that is already
  /// somewhere else, and must therefore act on nothing.
  ///
  /// Distinct from [playsHere] being false. That means the sound belongs to
  /// another surface, which is worth telling the user about — a pad flashes to
  /// confirm the tap went out. Inert means there is nothing to confirm, because
  /// the copy the user is looking at is handling it.
  bool get isInert => false;

}

/// The answer for the hidden twin of a widget being shown full screen. See
/// [HiddenWidgetTwin], which is the only thing that installs it.
class InertBoardAudioPolicy extends BoardAudioPolicy {

  const InertBoardAudioPolicy();

  @override
  bool get playsHere => false;

  @override
  bool get isInert => true;

}

/// Never plays. The external display's answer, and the safe default anywhere
/// the question hasn't been thought about.
///
/// A USB-C or AirPlay screen is a second *window*, not a second sound card. It
/// shares the host's audio device, so having it play too would double every
/// sound rather than move it.
class SilentBoardAudioPolicy extends BoardAudioPolicy {

  const SilentBoardAudioPolicy();

  @override
  bool get playsHere => false;

}

/// Plays whenever the presenter has kept audio on this device.
class PresenterBoardAudioPolicy extends BoardAudioPolicy {

  final AudioOutputController _output;

  const PresenterBoardAudioPolicy(this._output);

  @override
  bool get playsHere => _output.playsHere;

}

/// A viewer plays only when **both** switches agree: the presenter routed audio
/// to viewers, and this particular screen has had its sound switched on.
///
/// Both halves are load-bearing. Without the presenter's half, a viewer would
/// echo whatever the presenter is already playing. Without the viewer's half,
/// every student laptop watching would play too. And browsers would refuse
/// anyway, since audio needs a user gesture the toggle is what provides.
class ViewerBoardAudioPolicy extends BoardAudioPolicy {

  final bool Function() _presenterRoutedToViewers;
  final bool Function() _soundEnabledHere;

  const ViewerBoardAudioPolicy({
    required this._presenterRoutedToViewers,
    required this._soundEnabledHere,
  });

  @override
  bool get playsHere => _presenterRoutedToViewers() && _soundEnabledHere();

}

/// Provides the [BoardAudioPolicy] board widgets consult before playing.
///
/// Mirrors how [BoardAssets] provides byte loading. The editor doesn't wrap its
/// tree and falls back to the app-wide [AudioOutputController]. The
/// external-display isolate and the web viewer each wrap their board subtree
/// with the policy that suits them.
class BoardAudioScope extends InheritedWidget {

  final BoardAudioPolicy policy;

  const BoardAudioScope({super.key, required this.policy, required super.child});

  /// The nearest scope's policy, falling back to the presenter's own routing
  /// when the app services exist.
  ///
  /// With neither — the external-display isolate outside a scope — the answer is
  /// silence rather than sound. Getting this wrong in the quiet direction costs
  /// a missed effect. Getting it wrong the other way plays a sound twice in a
  /// room, which is the failure people actually notice.
  static BoardAudioPolicy of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BoardAudioScope>();
    if (scope != null) return scope.policy;
    if (GetIt.I.isRegistered<AudioOutputController>()) {
      return _presenterFallback ??= PresenterBoardAudioPolicy(GetIt.I<AudioOutputController>());
    }
    return const SilentBoardAudioPolicy();
  }

  // The controller is a stable app-wide singleton, so one fallback policy can
  // be shared for the life of the process.
  static BoardAudioPolicy? _presenterFallback;

  @override
  bool updateShouldNotify(BoardAudioScope oldWidget) => policy != oldWidget.policy;

}
