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
