import 'package:fluent_ui/fluent_ui.dart';

/// Shared styling for every [MenuFlyout] in the app, so all context/overflow
/// menus read as one squircle family and offer comfortable touch targets.
///
/// fluent's [MenuFlyout] isn't theme-driven (there is no `MenuFlyoutThemeData`),
/// so these helpers are applied at each call site. A [MenuFlyout]'s `shape` and
/// `itemMargin` propagate to its sub-menus automatically, so setting them on the
/// top-level flyout is enough.

/// Corner radius of the continuous-rectangle menu border.
const double kMenuCornerRadius = 12;

/// Vertical spacing around each menu item. Fluent's own item padding is a tight
/// 4px top/bottom (hardcoded, not themeable), so we widen the per-item margin to
/// grow the effective row pitch into a comfortable touch target. The horizontal
/// value matches fluent's default so item highlights still hug the menu edges.
const EdgeInsetsGeometry kMenuItemMargin = EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 6);

/// The continuous (squircle) border for menu flyouts, matching the app's other
/// squircle surfaces instead of fluent's default rounded corner. Pass to
/// [MenuFlyout.shape].
ShapeBorder continuousMenuShape(BuildContext context) {
  return ContinuousRectangleBorder(
    borderRadius: BorderRadius.circular(kMenuCornerRadius),
    side: BorderSide(color: FluentTheme.of(context).resources.surfaceStrokeColorFlyout),
  );
}
