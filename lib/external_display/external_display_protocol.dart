/// Shared message contract between the main app isolate and the
/// external-display isolate (run via [externalDisplayMain]). Both sides import
/// this file so the action names and payload keys never drift.
///
/// The plugin's `sendParameters(action, value)` bus carries a `value` that we
/// always encode as a JSON **string** (via [jsonEncode]) so nested, mixed-type
/// maps survive the platform channel's standard codec unchanged.
class ExternalDisplayProtocol {

  ExternalDisplayProtocol._();

  /// The entry-point function name registered with the plugin's `connect()`.
  static const String routeName = 'externalDisplayMain';

  /// Push the active board's full render state. `value` = jsonEncode of a map
  /// with [keyBoard], [keyWidgets], [keyDrawing].
  static const String actionBoard = 'board';

  /// No board is open; the external screen should show the idle placeholder.
  /// `value` is unused.
  static const String actionClear = 'clear';

  // Payload keys inside the actionBoard JSON.
  static const String keyBoard = 'board';
  static const String keyWidgets = 'widgets';
  static const String keyDrawing = 'drawing';

}
