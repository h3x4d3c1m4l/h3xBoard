import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/theme/app_theme.dart';

/// Opens a dialog the way this app opens dialogs: fluent's own entrance motion,
/// over a backdrop that blurs in behind it.
///
/// Every dialog in the app goes through here rather than fluent's [showDialog],
/// so the backdrop treatment is stated once. Fluent dims with a flat scrim
/// alone, which over a whiteboard full of drawings and widgets leaves the page
/// competing with the dialog; blurring it pushes the page back instead. The
/// blur ramps up with the dialog's own fade/scale rather than snapping on, so
/// opening a dialog reads as one movement.
///
/// Parameters mirror fluent's [showDialog] and are passed straight through.
/// Pass `useRootNavigator: false` to keep the dialog inside a nested router's
/// navigator (the boards overview does this).
Future<T?> showAppDialog<T extends Object?>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  bool useRootNavigator = true,
}) {
  final blurAmount = context.appTheme.dialogs.barrierBlur;
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return _BlurredDialogTransition(
        animation: animation,
        blurAmount: blurAmount,
        child: child,
      );
    },
  );
}

/// Fluent's dialog transition (fade + subtle scale) with the screen behind it
/// blurring in over the same animation.
///
/// The fade and scale are spelled out here rather than delegating to fluent's
/// default transition builder — that one is private, and the blur has to sit
/// *outside* the fade: a [BackdropFilter] under an [Opacity] would filter a
/// backdrop that is itself being composited, which reads as the page sliding
/// under glass instead of the glass thickening over it.
class _BlurredDialogTransition extends StatelessWidget {

  /// The route's entrance animation; runs backwards on dismissal, which takes
  /// the blur back out with it.
  final Animation<double> animation;

  /// The blur sigma at the end of the entrance (see [AppDialogStyles.barrierBlur]).
  final double blurAmount;

  final Widget child;

  const _BlurredDialogTransition({
    required this.animation,
    required this.blurAmount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      // The dialog itself doesn't depend on the animation — hand it to the
      // builder so only the filter/opacity/scale are rebuilt per frame.
      child: child,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        // Fluent curves the *scale* rather than the animation driving it, which
        // is why the dialog settles a hair under 1.0 instead of at it. Matched
        // exactly so dialogs keep the size they have always had.
        final scale = Curves.easeOut.transform(lerpDouble(1, 0.85, t)!);
        final progress = Curves.easeOut.transform(t);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount * progress, sigmaY: blurAmount * progress),
          child: Opacity(
            opacity: progress,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }

}
