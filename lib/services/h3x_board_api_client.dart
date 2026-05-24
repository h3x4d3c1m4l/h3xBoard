import 'dart:async';
import 'dart:convert';

import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/auth_response.dart';
import 'package:h3xboard/models/api/board_detail.dart';
import 'package:h3xboard/models/api/board_summary.dart';
import 'package:h3xboard/models/api/refresh_token_response.dart';
import 'package:h3xboard/models/api/whoami_response.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class H3xBoardApiClient {

  final String serverUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  int _nextRequestId = 1;
  final Map<int, Completer<dynamic>> _pending = {};

  H3xBoardApiClient({required this.serverUrl});

  bool get isConnected => _channel != null;

  Future<void> connect({String? accessToken}) async {
    final uri = accessToken != null
        ? Uri.parse('$serverUrl/ws/v1?token=$accessToken')
        : Uri.parse('$serverUrl/ws/v1');
    _channel = WebSocketChannel.connect(uri);
    await _channel!.ready;
    _subscription = _channel!.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<AuthResponse> login({required String username, required String password}) async {
    final result = await _call('auth.v1.login', {'username': username, 'password': password});
    return AuthResponse.fromJson(result as Map<String, dynamic>);
  }

  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final result = await _call('auth.v1.register', {
      'username': username,
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(result as Map<String, dynamic>);
  }

  Future<RefreshTokenResponse> refreshToken(String refreshToken) async {
    final result = await _call('auth.v1.refreshToken', {'refreshToken': refreshToken});
    return RefreshTokenResponse.fromJson(result as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _call('auth.v1.logout', <String, dynamic>{});
  }

  Future<WhoAmiResponse> whoami() async {
    final result = await _call('auth.v1.whoami', <String, dynamic>{});
    return WhoAmiResponse.fromJson(result as Map<String, dynamic>);
  }

  Future<List<BoardSummary>> listBoards() async {
    final result = await _call('boards.v1.list', <String, dynamic>{});
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

  /// Encodes and sends a JSON-RPC 2.0 request over the WebSocket sink, then
  /// returns a [Future] that resolves to the response's `result` value, or
  /// throws an [H3xBoardApiException] if the server returns an error object.
  Future<dynamic> _call(String method, dynamic params) {
    if (_channel == null) {
      throw const H3xBoardApiException(code: -1, message: 'Not connected');
    }
    final id = _nextRequestId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _channel!.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'id': id,
      'params': params,
    }));
    return completer.future;
  }

  /// Parses an incoming JSON-RPC 2.0 response and completes the matching
  /// [Completer] from [_pending]: with the `result` value on success, or with
  /// an [H3xBoardApiException] when the response contains an `error` object.
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

  /// Forwards a WebSocket stream error to every in-flight [Completer] in
  /// [_pending], clears the map, and nulls out [_channel].
  void _onError(Object error, StackTrace stackTrace) {
    for (final completer in _pending.values) {
      completer.completeError(error, stackTrace);
    }
    _pending.clear();
    _channel = null;
  }

  /// Called when the WebSocket stream closes. Rejects every in-flight
  /// [Completer] in [_pending] with a connection-closed
  /// [H3xBoardApiException], clears the map, and nulls out [_channel].
  void _onDone() {
    final error = const H3xBoardApiException(code: -1, message: 'WebSocket connection closed');
    for (final completer in _pending.values) {
      completer.completeError(error);
    }
    _pending.clear();
    _channel = null;
  }

}
