import 'package:flutter/widgets.dart';

/// Single source of truth for the app's continuous-rectangle shape metrics.
///
/// Controls (buttons, text fields) are kept *concentric* to the content dialog:
/// an inner rounded corner should be `outerRadius − gap`, where the gap is the
/// dialog's padding. Change [kDialogCornerRadius] and everything else follows.

/// Corner radius of the content dialog's continuous-rectangle border.
const double kDialogCornerRadius = 48;

/// The dialog's inner padding (fluent's `ContentDialogThemeData` default, also
/// the gap between the dialog edge and the controls inside it).
const double kDialogPadding = 20;

/// Concentric corner radius for controls inside the dialog padding — buttons and
/// text fields: `dialogRadius − padding`.
const double kControlCornerRadius = kDialogCornerRadius - kDialogPadding;

/// Shared inner padding for buttons and text fields, so they line up in height.
const EdgeInsetsGeometry kControlPadding = EdgeInsets.symmetric(vertical: 12, horizontal: 24);

/// Corner radius for fluent's *short* controls — a `ComboBox` closed state is a
/// fixed 32px high (fluent's `kPickerHeight`), less than half the height of a
/// [kControlPadding] button. At [kControlCornerRadius] the curves meet before
/// the edge has a chance to run straight and the squircle collapses into a
/// lozenge, so these get a radius scaled to their own height.
const double kShortControlCornerRadius = 18;

/// Inner padding for icon-only buttons. They carry no label to give room to, so
/// the wide [kControlPadding] would only make them look oversized; square
/// padding keeps them square (fluent's own default for a large icon button).
const EdgeInsetsGeometry kIconControlPadding = EdgeInsets.all(8);

/// Corner radius of the whiteboard canvas's continuous-rectangle border.
const double kBoardCornerRadius = 24;

/// Continuous (squircle) corner radii for the sub-board tab bar. The tab's inner
/// button hugs the outer indicator concentrically (outer − 1), matching the app's
/// squircle surfaces instead of fluent's default rounded corners.
const double kSubBoardTabRadius = 8;
const double kSubBoardTabButtonRadius = kSubBoardTabRadius - 1;

/// Inner padding of a sub-board tab's label button — also what the Exit button
/// uses, so the two top-bar controls sit at the same height. Named here because
/// the tab bar has to predict a tab's laid-out width before it exists.
const double kTabHorizontalPadding = 12;
const double kTabVerticalPadding = 6;

/// Corner radius of the board screen's Exit button. Rounder and quieter than the
/// app's squircle controls: it sits loose in the top bar, not on a surface.
const double kExitButtonRadius = 8;

/// Corner radius of tooltips' continuous-rectangle border.
const double kTooltipCornerRadius = 8;

/// Corner radius of a floating toolbar (the drawing tool bar, the text widget's
/// format bar) and the inner padding around the buttons it holds.
const double kToolbarCornerRadius = 32;
const EdgeInsetsGeometry kToolbarPadding = EdgeInsets.all(4);

/// Max width of centered page content — the board grid on the Boards screen and
/// the top bars on both the Boards and Board screens. Beyond this the content is
/// centered with equal gutters so the two top bars line up with the grid.
const double kMaxContentWidth = 1240;

/// Horizontal gutter between the screen edge and centered page content.
const double kContentHorizontalPadding = 24;
