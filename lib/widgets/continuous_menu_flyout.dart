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

/// Outer margin for menu items that [AppMenuFlyout] does **not** render as a
/// padded tile (notably [MenuFlyoutSeparator]). Regular item rows get their
/// comfortable, fully-clickable touch height from padding *inside* the row
/// instead — see `_buildAppMenuTile` in `app_menu_flyout.dart` — so this stays
/// horizontal-only to avoid re-introducing dead, unclickable gaps between rows.
const EdgeInsetsGeometry kMenuItemMargin = EdgeInsetsDirectional.symmetric(horizontal: 4);

/// The continuous (squircle) border for menu flyouts, matching the app's other
/// squircle surfaces instead of fluent's default rounded corner. Pass to
/// [MenuFlyout.shape].
ShapeBorder continuousMenuShape(BuildContext context) {
  return ContinuousRectangleBorder(
    borderRadius: BorderRadius.circular(kMenuCornerRadius),
    side: BorderSide(color: FluentTheme.of(context).resources.surfaceStrokeColorFlyout),
  );
}
