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

  /// One live-share protocol frame. `value` = jsonEncode of a
  /// `LiveShareMessage` envelope — the same vocabulary web viewers receive
  /// through the backend; the bus is just the local transport for it.
  static const String actionMessage = 'message';

  /// Bus-only side channel pushing the bytes of a file the mirrored board
  /// references (the isolate can't fetch them itself). `value` = jsonEncode of
  /// `{fileId, bytes}` with [keyBytes] base64-encoded, or null when the main
  /// isolate failed to fetch the file.
  static const String actionAsset = 'asset';

  // Payload keys inside the actionAsset JSON.
  static const String keyFileId = 'fileId';
  static const String keyBytes = 'bytes';

}
