import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

/// The smallest gap the app keeps between a dialog and the edge of the screen.
///
/// Only a *minimum*: where the OS already holds content off the edge (a notch,
/// a status bar, a home indicator) that inset is used instead — see
/// [buildDialogInsets].
const double kDialogInsetGap = 24;

/// Insets a centered dialog from the screen edges, and — when [avoidKeyboard] —
/// lifts it above the on-screen keyboard, mirroring Material's [Dialog].
///
/// The safe-area insets and [kDialogInsetGap] are **merged, not stacked**: a
/// notch already holds the dialog well clear of the edge, so adding the gap on
/// top of it only spends space the content needs. This is the whole reason
/// `showAppDialog` pushes its own route — fluent's `FluentDialogRoute` wraps
/// every dialog in a hardcoded [SafeArea] that cannot be turned off, which
/// stacked ~59px of status bar and this 24px into 83px of dead space above the
/// card while the keyboard ate the bottom.
///
/// The keyboard height ([MediaQueryData.viewInsets] bottom) becomes extra bottom
/// padding, animated in sync with the keyboard as it slides in. The child gets
/// both insets removed, so a nested [SafeArea] or a text field inside the dialog
/// doesn't apply them a second time.
///
/// Pass `avoidKeyboard: false` for the large content panels (Settings, Add
/// Widget, Emoji picker): shifting or shrinking a 760px panel by the keyboard
/// height doesn't help, but they still want the safe-area treatment.
Widget buildDialogInsets(
  BuildContext context, {
  required Widget child,
  bool avoidKeyboard = true,
}) {

  final media = MediaQuery.of(context);
  // `padding` rather than `viewPadding`: it already collapses to zero on the
  // side the keyboard covers, so the home indicator is not counted twice.
  final safe = media.padding;
  final keyboard = avoidKeyboard ? media.viewInsets.bottom : 0.0;

  return AnimatedPadding(
    // Match Material's Dialog.insetAnimationDuration / insetAnimationCurve so the
    // dialog tracks the keyboard's own slide-in timing.
    padding: EdgeInsets.only(
      left: math.max(safe.left, kDialogInsetGap),
      top: math.max(safe.top, kDialogInsetGap),
      right: math.max(safe.right, kDialogInsetGap),
      bottom: math.max(safe.bottom, kDialogInsetGap) + keyboard,
    ),
    duration: const Duration(milliseconds: 100),
    curve: Curves.decelerate,
    // Both removals are folded into one MediaQueryData. Nesting the
    // MediaQuery.removeX helpers would not work: each reads its data from the
    // *context* it is given, so the inner one would rebuild from the original
    // data and undo the outer one.
    child: MediaQuery(
      data: media
          .removePadding(removeLeft: true, removeTop: true, removeRight: true, removeBottom: true)
          .removeViewInsets(removeLeft: true, removeTop: true, removeRight: true, removeBottom: true),
      child: child,
    ),
  );
}
