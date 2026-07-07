import 'package:fluent_ui/fluent_ui.dart';

/// A [FlyoutController] that does not auto-close its flyout when the view
/// metrics change.
///
/// The base [FlyoutController] listens as a [WidgetsBindingObserver] and closes
/// any open flyout from [didChangeMetrics]. On iOS that callback fires as the
/// safe-area / viewport insets settle right after the flyout route is pushed, so
/// the flyout is dismissed before it is ever visible — flyouts simply never
/// appear. (On web a tap triggers no metrics change, which is why the same code
/// works there.)
///
/// Suppressing the metrics-driven close keeps flyouts working on iOS. They stay
/// dismissible by tapping outside (the barrier) or pressing Esc; the only thing
/// given up is auto-dismiss on rotation, which is fine for the app's short menus.
class StableFlyoutController extends FlyoutController {

  @override
  void didChangeMetrics() {
    // Intentionally does nothing — see the class docs.
  }

}
