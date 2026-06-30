import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/board_detail.dart';
import 'package:h3xboard/models/api/board_summary.dart';
import 'package:h3xboard/models/api/browse_files_result.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum H3xConnectionState { connected, reconnecting, disconnected }

class H3xBoardApiClient {

  final String serverUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  int _nextRequestId = 1;
  final Map<int, Completer<dynamic>> _pending = {};

  bool _intentionalDisconnect = false;
  bool _reconnecting = false;

  /// Validates the session out-of-band (via REST `whoami`) to tell a transient
  /// network failure apart from a confirmed expiry. Returns `true` when the
  /// session is valid, `false` when it is definitively invalid (HTTP 401), and
  /// `null` when it could not be determined (network error → treat as transient).
  Future<bool?> Function()? sessionValidator;

  /// Called once a reconnect attempt establishes that the session is no longer
  /// valid; the app uses this to send the user back to the login screen.
  void Function()? onSessionExpired;

  /// Observable connection state, used to drive the "Reconnecting…" banner.
  final ValueNotifier<H3xConnectionState> connectionState =
      ValueNotifier(H3xConnectionState.disconnected);

  H3xBoardApiClient({required this.serverUrl});

  bool get isConnected => _channel != null;

  Future<void> connect() async {
    _intentionalDisconnect = false;
    await _open();
    connectionState.value = H3xConnectionState.connected;
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    connectionState.value = H3xConnectionState.disconnected;
  }

  /// Opens the WebSocket channel and starts listening. Throws if the handshake
  /// fails (the caller decides whether to retry).
  Future<void> _open() async {
    final wsUrl = serverUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsUrl/ws/v1');
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    _channel = channel;
    _subscription = channel.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
    );
  }

  Future<List<BoardSummary>> listBoards() async {
    final result = await _call('boards.v1.list');
    return (result as List<dynamic>)
        .map((item) => BoardSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BoardDetail> getBoard(String id) async {
    final result = await _call('boards.v1.get', id);
    return BoardDetail.fromJson(result as Map<String, dynamic>);
  }

  Future<BoardDetail> createBoard({required String title, Map<String, dynamic>? data}) async {
    final params = <String, dynamic>{'title': title};
    if (data != null) params['data'] = data;
    final result = await _call('boards.v1.create', params);
    return BoardDetail.fromJson(result as Map<String, dynamic>);
  }

  Future<BoardDetail> updateBoard({
    required String id,
    String? title,
    Map<String, dynamic>? data,
  }) async {
    final params = <String, dynamic>{'id': id};
    if (title != null) params['title'] = title;
    if (data != null) params['data'] = data;
    final result = await _call('boards.v1.update', params);
    return BoardDetail.fromJson(result as Map<String, dynamic>);
  }

  Future<void> deleteBoard(String id) async {
    await _call('boards.v1.delete', id);
  }

  /// Lists one virtual folder — its immediate sub-folders and the files directly
  /// in it (metadata only, no bytes). [path] is the folder to list (null/"" =
  /// root). The bytes themselves are uploaded/downloaded over REST; see
  /// `H3xBoardFileService`.
  Future<BrowseFilesResult> browseFiles([String? path]) async {
    final result = await _call('files.v1.browse', <String, dynamic>{'path': path ?? ''});
    return BrowseFilesResult.fromJson(result as Map<String, dynamic>);
  }

  /// Permanently deletes a file (bytes and metadata). There is no undo.
  Future<void> deleteFile(String id) async {
    await _call('files.v1.delete', id);
  }

  /// Fetches every user setting as a `key → decoded JSON value` map. Keys are
  /// dotted strings (e.g. `ui.language`); values are whatever JSON was stored.
  Future<Map<String, dynamic>> getAllSettings() async {
    final result = await _call('settings.v1.getAll', <String, dynamic>{});
    return {
      for (final entry in (result as List<dynamic>))
        (entry as Map<String, dynamic>)['key'] as String: entry['value'],
    };
  }

  /// Patches a single setting. Only the named [key] is touched server-side, so
  /// concurrent edits to other keys are never clobbered. [value] is encoded as
  /// JSON (string, bool, number, list or map).
  Future<void> setSetting(String key, dynamic value) async {
    await _call('settings.v1.set', <String, dynamic>{'key': key, 'value': value});
  }

  /// Removes a single setting, reverting it to its server-side default.
  Future<void> deleteSetting(String key) async {
    await _call('settings.v1.delete', <String, dynamic>{'key': key});
  }

  Future<dynamic> _call(String method, [dynamic params]) {
    if (_channel == null) {
      throw const H3xBoardApiException(code: -1, message: 'Not connected');
    }
    final id = _nextRequestId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    final message = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': method,
      'id': id,
    };
    if (params != null) message['params'] = [params];
    _channel!.sink.add(jsonEncode(message));
    return completer.future;
  }

  void _onMessage(dynamic raw) {
    final response = jsonDecode(raw as String) as Map<String, dynamic>;
    final id = response['id'] as int?;
    if (id == null) return;
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (response.containsKey('error')) {
      final error = response['error'] as Map<String, dynamic>;
      completer.completeError(H3xBoardApiException(
        code: error['code'] as int,
        message: error['message'] as String,
      ));
    } else {
      completer.complete(response['result']);
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    _failPending(error, stackTrace);
    _channel = null;
    _maybeReconnect();
  }

  void _onDone() {
    const error = H3xBoardApiException(code: -1, message: 'WebSocket connection closed');
    _failPending(error);
    _channel = null;
    _maybeReconnect();
  }

  void _failPending(Object error, [StackTrace? stackTrace]) {
    for (final completer in _pending.values) {
      completer.completeError(error, stackTrace);
    }
    _pending.clear();
  }

  /// Kicks off a background reconnect loop after an *unexpected* disconnect.
  void _maybeReconnect() {
    if (_intentionalDisconnect || _reconnecting) return;
    connectionState.value = H3xConnectionState.reconnecting;
    unawaited(_reconnect());
  }

  /// Retries the connection with exponential backoff (capped at 15s) for as long
  /// as the failures look transient. When [sessionValidator] reports the session
  /// is definitively invalid, stops and fires [onSessionExpired].
  Future<void> _reconnect() async {
    _reconnecting = true;
    var attempt = 0;
    try {
      while (!_intentionalDisconnect && _channel == null) {
        try {
          await _open();
          connectionState.value = H3xConnectionState.connected;
          return;
        } catch (_) {
          final valid = await sessionValidator?.call();
          if (valid == false) {
            connectionState.value = H3xConnectionState.disconnected;
            onSessionExpired?.call();
            return;
          }
          await Future<void>.delayed(_backoff(attempt++));
        }
      }
    } finally {
      _reconnecting = false;
    }
  }

  Duration _backoff(int attempt) {
    final seconds = 1 << attempt; // 1, 2, 4, 8, 16, ...
    return Duration(seconds: seconds > 15 ? 15 : seconds);
  }

}
