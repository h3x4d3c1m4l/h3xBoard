import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/components/dialogs/dialog_insets.dart';

/// The scrim a modal surface lays over the page, under its blur. Exposed
/// because not every use of this treatment is a route with a [ModalBarrier] to
/// paint it — the mirrored full-screen widget on a live-share receiver paints
/// its own.
/// Kept at 70% rather than darker because dialogs stack (board settings → colour
/// picker, image editor → file picker): two barriers compose as `1-(1-a)²`, so
/// this already reads as 91% on the inner one.
const Color kAppBarrierColor = Color(0xB3000000);

/// Opens a dialog the way this app opens dialogs: fluent's own entrance motion,
/// over a backdrop that blurs in behind it.
///
/// Every dialog in the app goes through here, so the backdrop treatment is
/// stated once. Fluent dims with a flat scrim alone, which over a whiteboard
/// full of drawings and widgets leaves the page competing with the dialog;
/// blurring it pushes the page back instead. The blur ramps up with the dialog's
/// own fade/scale rather than snapping on, so opening a dialog reads as one
/// movement.
///
/// The route is pushed here rather than through fluent's [showDialog] for one
/// reason: `FluentDialogRoute` wraps every dialog in a [SafeArea] that cannot be
/// turned off (it documents a `useSafeArea` argument it never accepts). Stacked
/// under [buildDialogInsets]'s own gap that spent the notch twice, leaving ~83px
/// of dead space above a dialog while the keyboard ate the bottom. Everything
/// else fluent's route does is reproduced below.
///
/// Parameters mirror fluent's [showDialog]. Pass `useRootNavigator: false` to
/// keep the dialog inside a nested router's navigator (the boards overview does
/// this).
Future<T?> showAppDialog<T extends Object?>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  bool useRootNavigator = true,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    buildAppDialogRoute<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
    ),
  );
}

/// The route [showAppDialog] pushes, for a caller that needs the route object
/// itself — the full-screen widget listens to its animation to know when the
/// flight has landed, and drives its own motion from it.
///
/// [fadeContent] off leaves the backdrop blurring in but stops the content
/// fading and scaling with it: a surface that flies in from a real place on the
/// page must not fade while it does, or it blinks at both ends of the flight.
RawDialogRoute<T> buildAppDialogRoute<T extends Object?>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  bool useRootNavigator = true,
  Duration? transitionDuration,
  bool fadeContent = true,
}) {

  assert(debugCheckHasFluentLocalizations(context), 'FluentLocalizations are required.');
  final blurAmount = context.appTheme.dialogs.barrierBlur;
  final theme = FluentTheme.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  // The dialog is built under the navigator rather than under the caller, so any
  // inherited theme between the two has to be carried across by hand.
  final themes = InheritedTheme.capture(from: context, to: navigator.context);

  return RawDialogRoute<T>(
    barrierDismissible: barrierDismissible,
    barrierColor: kAppBarrierColor,
    barrierLabel: FluentLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration:
        transitionDuration ?? theme?.fastAnimationDuration ?? const Duration(milliseconds: 300),
    pageBuilder: (routeContext, animation, secondaryAnimation) {
      return Actions(
        actions: {DismissIntent: _PopOnDismissAction(routeContext)},
        child: FocusScope(
          autofocus: true,
          child: themes.wrap(Builder(builder: builder)),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (!fadeContent) {
        return BlurredBackdrop(animation: animation, blurAmount: blurAmount, child: child);
      }
      return BlurredBackdropTransition(
        animation: animation,
        blurAmount: blurAmount,
        child: child,
      );
    },
  );
}

/// Closes the dialog on Escape, the way fluent's own dialog route does (its
/// action is private, so this restates it).
class _PopOnDismissAction extends DismissAction {

  final BuildContext context;

  _PopOnDismissAction(this.context);

  @override
  void invoke(covariant DismissIntent intent) => Navigator.of(context).pop();

}

/// The screen behind a modal surface blurring in over its entrance animation.
///
/// Separate from the fade and scale it is usually paired with for two reasons.
/// The blur has to sit *outside* the fade — a [BackdropFilter] under an
/// [Opacity] would filter a backdrop that is itself being composited, which
/// reads as the page sliding under glass instead of the glass thickening over
/// it. And a surface whose content arrives from somewhere real (a board widget
/// flying up into full screen) wants the blur without the fade: fading it in
/// from nothing would undo the point of flying it from where it already was.
class BlurredBackdrop extends StatelessWidget {

  /// The route's entrance animation; runs backwards on dismissal, which takes
  /// the blur back out with it.
  final Animation<double> animation;

  /// The blur sigma at the end of the entrance (see [AppDialogStyles.barrierBlur]).
  final double blurAmount;

  final Widget child;

  const BlurredBackdrop({
    super.key,
    required this.animation,
    required this.blurAmount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      // The content doesn't depend on the animation — hand it to the builder so
      // only the filter is rebuilt per frame.
      child: child,
      builder: (context, child) {
        final progress = Curves.easeOut.transform(animation.value.clamp(0.0, 1.0));
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount * progress, sigmaY: blurAmount * progress),
          child: child,
        );
      },
    );
  }

}

/// Fluent's dialog transition (fade + subtle scale) over a [BlurredBackdrop].
///
/// The fade and scale are spelled out here rather than delegating to fluent's
/// default transition builder — that one is private.
class BlurredBackdropTransition extends StatelessWidget {

  /// The route's entrance animation; runs backwards on dismissal.
  final Animation<double> animation;

  /// The blur sigma at the end of the entrance (see [AppDialogStyles.barrierBlur]).
  final double blurAmount;

  final Widget child;

  const BlurredBackdropTransition({
    super.key,
    required this.animation,
    required this.blurAmount,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlurredBackdrop(
      animation: animation,
      blurAmount: blurAmount,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final t = animation.value.clamp(0.0, 1.0);
          // Fluent curves the *scale* rather than the animation driving it, which
          // is why the dialog settles a hair under 1.0 instead of at it. Matched
          // exactly so dialogs keep the size they have always had.
          final scale = Curves.easeOut.transform(lerpDouble(1, 0.85, t)!);
          return Opacity(
            opacity: Curves.easeOut.transform(t),
            child: Transform.scale(scale: scale, child: child),
          );
        },
      ),
    );
  }

}
