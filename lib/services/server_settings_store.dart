import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user-chosen API server URL across launches on every platform
/// Flutter supports (web, desktop, mobile), backed by shared_preferences.
///
/// Kept intentionally tiny: the server URL is the one piece of configuration the
/// app must remember *before* it can reach the server, so it cannot live in the
/// server-side `settings.v1.*` store like the rest of the preferences.
class ServerSettingsStore {

  static const String _serverUrlKey = 'h3xboard.serverUrl';

  final SharedPreferencesAsync _prefs;

  ServerSettingsStore([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();

  /// The stored server URL, or `null` when the user has never overridden it (the
  /// app then falls back to the compile-time/runtime default).
  Future<String?> getServerUrl() async {
    final value = await _prefs.getString(_serverUrlKey);
    return (value != null && value.isNotEmpty) ? value : null;
  }

  Future<void> setServerUrl(String url) => _prefs.setString(_serverUrlKey, url);

  Future<void> clearServerUrl() => _prefs.remove(_serverUrlKey);

}
