import 'package:fluent_ui/fluent_ui.dart';

/// Gap between the bar and the control hanging off it. Matches the gap the
/// scaffold puts between a bar and the board edge, so the two read as one rhythm.
const double _kTrailingGap = 8;

/// Hangs [trailing] off the end of [child] without moving [child] off centre.
///
/// [BoardScaffold] centres a docked bar on its edge (`crossAxisAlignment.center`
/// in ring 2/3, and the bar slot shrink-wraps). So a plain `Row(children: [bar,
/// button])` would centre the *pair*, sliding the bar left by half the button's
/// width — the bar would visibly drift the moment a button was added beside it,
/// and again if the button's size ever changed.
///
/// An invisible copy of [trailing] on the leading side restores the balance: the
/// flex is symmetric about [child], whatever [trailing] measures. Same trick as
/// [BalancedSide] in the top bar, in a [Flex] instead of a [Stack] — here the
/// counterweight must take up room beside the child rather than under it.
///
/// [direction] follows the bar's own axis, so a toolbar docked left or right
/// gets its trailing control below instead of beside.
///
/// [trailing] is built twice, so it MUST NOT carry a [GlobalKey] and MUST NOT own
/// state that two live copies would fight over. A plain [Key] is fine — the copies
/// sit under different parents, so they never collide as siblings.
class BalancedTrailing extends StatelessWidget {

  /// The bar to keep centred.
  final Widget child;

  /// The control to place after it.
  final Widget trailing;

  /// The bar's layout axis — horizontal when docked top/bottom.
  final Axis direction;

  const BalancedTrailing({
    super.key,
    required this.child,
    required this.trailing,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Spacer only: it must not paint, take pointers, take focus, or reach
        // semantics — it is the same widget announced twice otherwise.
        ExcludeFocus(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: Opacity(opacity: 0, child: trailing),
            ),
          ),
        ),
        const SizedBox.square(dimension: _kTrailingGap),
        // Loose, so the bar still shrink-wraps while it fits. What this changes is
        // that the bar now gets a *bounded* main-axis constraint: a Flex hands
        // non-flexible children unbounded ones, under which the bar's own
        // [BarScrollArea] would take its natural size and never scroll.
        Flexible(child: child),
        const SizedBox.square(dimension: _kTrailingGap),
        trailing,
      ],
    );
  }

}
