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

/// The account chip in the boards top bar — the inset around its initials tile.
///
/// Picked so the chip stands exactly as tall as the search box beside it: the
/// text box is [kControlPadding]'s 12 above and below a line of text (44px), and
/// the chip is this inset above and below its [kAccountTileSize] tile. The two
/// controls sit side by side, so they have to agree on height as well as on
/// [kControlCornerRadius].
const double kAccountChipInset = 6;

/// The square the account chip draws the user's initials on.
const double kAccountTileSize = 32;

/// That square's corner radius: the largest a tile this size can take, which is
/// half its side.
///
/// Deliberately *not* concentric with the chip around it. Concentric would be
/// `kControlCornerRadius - kAccountChipInset` = 22, and unlike a rounded
/// rectangle a [ContinuousRectangleBorder] does not clamp an over-large radius —
/// past half the side its corner curves eat the straight edges, bowing them
/// inward, and by 28 the shape is visibly deformed and painting outside its own
/// box. This is the trap [kShortControlCornerRadius] exists for, met from the
/// other direction: there the control is too short for the radius, here the tile
/// is.
const double kAccountTileCornerRadius = kAccountTileSize / 2;

/// Corner radius of the whiteboard canvas's continuous-rectangle border.
const double kBoardCornerRadius = 24;

/// Corner radius of a board widget's own surface — the card a clock or a to-do
/// list draws itself on. Generous, because these are canvas content rather than
/// app chrome: they read as objects placed on the board, and the softer corner
/// is most of what says so.
///
/// Safe to raise as far as you like: `BoardWidgetSurface` clamps it to half the
/// shortest side, so a card too small to take it stops at its own pill rather
/// than going misshapen. The small ones are already there — the clock is 100
/// units tall, so it caps at 50 whatever this says.
const double kBoardWidgetCornerRadius = 64;

/// Corner radius of a board widget's header bar. Half the card's, so the bar
/// sitting directly above it reads as belonging to it rather than echoing it.
const double kWidgetHeaderCornerRadius = 24;

/// The small controls *on* the header bar — the hover squares and the Done pill.
/// Left where they are while the bar grew: these are 40 units across, and at the
/// bar's radius the curves would meet before the edge had a chance to run
/// straight, which is the same trap [kShortControlCornerRadius] exists for.
const double kWidgetHeaderControlCornerRadius = 8;

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
