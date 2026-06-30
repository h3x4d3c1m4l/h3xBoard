import 'package:fluent_ui/fluent_ui.dart';

/// The language the app is displayed in. [system] follows the OS/browser locale;
/// the others force a specific locale. The [wireValue] is what gets persisted
/// server-side under the `ui.language` key.
enum AppLanguage {

  system('system', null),
  english('en', Locale('en')),
  dutch('nl', Locale('nl'));

  const AppLanguage(this.wireValue, this.locale);

  /// The value stored server-side (`'system'`, `'en'`, `'nl'`).
  final String wireValue;

  /// The forced locale, or `null` for [system] (follow the device).
  final Locale? locale;

  /// Parses a persisted value, falling back to [system] for unknown/missing input.
  static AppLanguage fromWire(Object? value) =>
      values.firstWhere((l) => l.wireValue == value, orElse: () => system);

}

/// Which edge of the board a bar (color selection bar / tool bar) is docked to.
enum BarPosition {

  left('left'),
  right('right'),
  top('top'),
  bottom('bottom');

  const BarPosition(this.wireValue);

  /// The value stored server-side (`'left'`, `'right'`, `'top'`, `'bottom'`).
  final String wireValue;

  /// The bar's main-axis orientation at this position: vertical when docked to a
  /// side, horizontal when docked to the top or bottom.
  Axis get axis => switch (this) {
    BarPosition.left || BarPosition.right => Axis.vertical,
    BarPosition.top || BarPosition.bottom => Axis.horizontal,
  };

  /// Parses a persisted value, falling back to [fallback] for unknown/missing input.
  static BarPosition fromWire(Object? value, BarPosition fallback) =>
      values.firstWhere((p) => p.wireValue == value, orElse: () => fallback);

}

/// When both bars are docked to the same edge, which one comes first (nearest the
/// start of the edge — top for a side edge, left for a top/bottom edge).
enum BarOrder {

  toolBarFirst('toolBar'),
  colorBarFirst('colorBar');

  const BarOrder(this.wireValue);

  /// The value stored server-side (`'toolBar'`, `'colorBar'`).
  final String wireValue;

  /// Parses a persisted value, falling back to [toolBarFirst] for unknown/missing input.
  static BarOrder fromWire(Object? value) =>
      values.firstWhere((o) => o.wireValue == value, orElse: () => toolBarFirst);

}
