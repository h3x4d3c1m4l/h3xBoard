import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:h3xboard/models/api/server_info.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/services/server_settings_store.dart';

/// Owns which API server the app talks to and the latest unauthenticated
/// [ServerInfo] fetched from it.
///
/// Changing the URL re-points every networking service ([H3xBoardAuthService],
/// [H3xBoardFileService], [H3xBoardApiClient]) at the new host, persists the
/// choice via [ServerSettingsStore], and re-fetches [serverInfo]. The fetched
/// info is exposed as a [ValueNotifier] so any screen can react to it (e.g. the
/// warning banner) instead of each fetching it itself.
///
/// Registered as a GetIt singleton in `setupServices`.
class ServerController {

  final H3xBoardAuthService _auth;
  final H3xBoardFileService _files;
  final H3xBoardApiClient _api;
  final ServerSettingsStore _store;

  String _serverUrl;

  ServerController({
    required String initialUrl,
    required this._auth,
    required this._files,
    required this._api,
    required this._store,
  }) : _serverUrl = normalizeUrl(initialUrl) {
    // Whenever the socket drops (logout, expiry, or a failed reconnect), refresh
    // the server info so any warning/capabilities are up to date on the login
    // screen the user lands on.
    _api.connectionState.addListener(_onConnectionStateChanged);
  }

  /// The current API base URL (trimmed, no trailing slash).
  String get serverUrl => _serverUrl;

  /// The most recent server capabilities/warning, or `null` before the first
  /// successful fetch (or after a failed refresh).
  final ValueNotifier<ServerInfo?> serverInfo = ValueNotifier<ServerInfo?>(null);

  /// Re-points every service at [url] (when it actually changed), persists it,
  /// and refreshes [serverInfo]. A blank URL is ignored except for the refresh,
  /// so the caller can also use this to simply retry the current server.
  Future<void> setServerUrl(String url) async {
    final normalized = normalizeUrl(url);
    if (normalized.isNotEmpty && normalized != _serverUrl) {
      _serverUrl = normalized;
      _auth.updateBaseUrl(normalized);
      _files.updateBaseUrl(normalized);
      _api.serverUrl = normalized;
      await _store.setServerUrl(normalized);
    }
    await refreshServerInfo();
  }

  /// Re-fetches [serverInfo] from the current server. Never throws; on failure
  /// the notifier is cleared to `null`.
  Future<void> refreshServerInfo() async {
    try {
      serverInfo.value = await _auth.serverInfo();
    } catch (_) {
      serverInfo.value = null;
    }
  }

  void _onConnectionStateChanged() {
    if (_api.connectionState.value == H3xConnectionState.disconnected) {
      unawaited(refreshServerInfo());
    }
  }

  /// Trims surrounding whitespace and any trailing slashes so URLs compare and
  /// concatenate predictably.
  static String normalizeUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

}
