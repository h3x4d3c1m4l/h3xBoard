import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/components/board_audio_scope.dart';

/// Wraps a board widget that may be the *hidden twin* of one shown full screen.
///
/// While a widget flies to and from full screen it is alive twice. One copy is
/// the one the user is looking at. The other is this one, kept laid out on the
/// board so the flight has something to land on. Dropping it from the Stack
/// instead would tear its body down mid-flight, losing a dice roll or a decoded
/// image. It would then start over on the way back.
///
/// Rendering is what the twin is for. Acting is not. Both copies are handed the
/// same config, so both see a trigger seed change, and a sound pad that acts on
/// it twice plays every tap twice. [InertBoardAudioPolicy] is how a widget finds
/// out which copy it is.
///
/// **This widget stays in the tree whether or not [isTwin] holds**, and toggles
/// its flags instead of being wrapped around the child only while flying. That
/// is the whole point: inserting a parent reparents everything below it, which
/// destroys the State the flight exists to preserve. Callers therefore wrap
/// unconditionally and pass the flag.
class HiddenWidgetTwin extends StatelessWidget {

  /// Whether this copy is the hidden one.
  ///
  /// False leaves every wrapper inert. `IgnorePointer(ignoring: false)` passes
  /// hits through, `Opacity` at 1 paints without a layer, and the scope
  /// re-states the policy already in force above it.
  final bool isTwin;

  final Widget child;

  const HiddenWidgetTwin({super.key, required this.isTwin, required this.child});

  @override
  Widget build(BuildContext context) {
    // Read from above this widget's own scope, so a non-twin passes the
    // surface's real policy straight through.
    final policy = isTwin ? const InertBoardAudioPolicy() : BoardAudioScope.of(context);
    return IgnorePointer(
      ignoring: isTwin,
      child: Opacity(
        opacity: isTwin ? 0 : 1,
        child: BoardAudioScope(policy: policy, child: child),
      ),
    );
  }

}
