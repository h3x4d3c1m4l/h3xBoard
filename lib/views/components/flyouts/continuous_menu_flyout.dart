import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/theme/shape_metrics.dart';

/// Shared styling for every [MenuFlyout] in the app, so all context/overflow
/// menus read as one squircle family and offer comfortable touch targets.
///
/// fluent's [MenuFlyout] isn't theme-driven (there is no `MenuFlyoutThemeData`),
/// so these helpers are applied at each call site. A [MenuFlyout]'s `shape` and
/// `itemMargin` propagate to its sub-menus automatically, so setting them on the
/// top-level flyout is enough.

/// Corner radius of the continuous-rectangle menu border. Matches the board
/// cards/buttons on the Boards screen ([kControlCornerRadius]) so every squircle
/// surface in the app reads as one family — at a smaller radius the continuous
/// corner is barely perceptible and menus read as plain rounded rectangles.
const double kMenuCornerRadius = kControlCornerRadius;

/// Horizontal inset of each menu item (its row highlight) from the menu's inner
/// edge. The flyout content adds no horizontal padding, so this margin is the
/// whole gap between the menu border and an item's highlight — and thus the gap
/// used to keep the highlight's corner concentric with the menu border.
const double kMenuItemHorizontalMargin = 4;

/// Concentric corner radius for a menu item's hover/pressed highlight:
/// `menuRadius − margin`, mirroring the dialog→control relationship in
/// `shape_metrics.dart` so the highlight tucks evenly inside the menu's own
/// continuous corner. [ContinuousRectangleBorder] clamps this to half the row
/// height, so at large menu radii the highlight reads as a rounded bar.
const double kMenuItemCornerRadius = kMenuCornerRadius - kMenuItemHorizontalMargin;

/// Outer margin for menu items that [AppMenuFlyout] does **not** render as a
/// padded tile (notably [MenuFlyoutSeparator]). Regular item rows get their
/// comfortable, fully-clickable touch height from padding *inside* the row
/// instead — see `_buildAppMenuTile` in `app_menu_flyout.dart` — so this stays
/// horizontal-only to avoid re-introducing dead, unclickable gaps between rows.
const EdgeInsetsGeometry kMenuItemMargin = EdgeInsetsDirectional.symmetric(horizontal: kMenuItemHorizontalMargin);

/// The continuous (squircle) border for menu flyouts, matching the app's other
/// squircle surfaces instead of fluent's default rounded corner. Pass to
/// [MenuFlyout.shape].
ShapeBorder continuousMenuShape(BuildContext context) {
  return ContinuousRectangleBorder(
    borderRadius: BorderRadius.circular(kMenuCornerRadius),
    side: BorderSide(color: FluentTheme.of(context).resources.surfaceStrokeColorFlyout),
  );
}
