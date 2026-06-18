import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/auth_response.dart';
import 'package:h3xboard/models/api/server_info.dart';
import 'package:h3xboard/models/api/whoami_response.dart';
import 'package:http/browser_client.dart';

part 'h3x_board_auth_service.chopper.dart';

@ChopperApi()
abstract class _H3xBoardAuthChopperService extends ChopperService {

  static _H3xBoardAuthChopperService _create(ChopperClient client) =>
      _$_H3xBoardAuthChopperService(client);

  @POST(path: '/api/v1/auth/login')
  Future<Response> login(@Body() Map<String, dynamic> body);

  @POST(path: '/api/v1/auth/register')
  Future<Response> register(@Body() Map<String, dynamic> body);

  @POST(path: '/api/v1/auth/logout')
  Future<Response> logout();

  @GET(path: '/api/v1/auth/whoami')
  Future<Response> whoami();

  @GET(path: '/api/v1/server/info')
  Future<Response> serverInfo();

}

class H3xBoardAuthService {

  final _H3xBoardAuthChopperService _service;

  H3xBoardAuthService._(this._service);

  static H3xBoardAuthService create(String baseUrl) {
    final httpClient = BrowserClient()..withCredentials = true;
    final chopperClient = ChopperClient(
      baseUrl: Uri.parse(baseUrl),
      client: httpClient,
      converter: JsonConverter(),
      services: [],
    );
    return H3xBoardAuthService._(_H3xBoardAuthChopperService._create(chopperClient));
  }

  Future<AuthResponse> login({required String email, required String password}) async {
    final response = await _service.login({'email': email, 'password': password});
    _requireSuccess(response);
    return AuthResponse.fromJson(response.body as Map<String, dynamic>);
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final response = await _service.register({
      'email': email,
      'password': password,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
    });
    _requireSuccess(response);
    return AuthResponse.fromJson(response.body as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _service.logout();
  }

  /// Returns the current user, or null when the session is not authenticated.
  Future<WhoAmiResponse?> whoami() async {
    final response = await _service.whoami();
    if (response.statusCode == 401) return null;
    _requireSuccess(response);
    return WhoAmiResponse.fromJson(response.body as Map<String, dynamic>);
  }

  /// Fetches unauthenticated server capabilities (e.g. whether registration is
  /// open). Designed to grow over time alongside the server's `ServerInfo`.
  Future<ServerInfo> serverInfo() async {
    final response = await _service.serverInfo();
    _requireSuccess(response);
    return ServerInfo.fromJson(response.body as Map<String, dynamic>);
  }

  void _requireSuccess(Response<dynamic> response) {
    if (response.isSuccessful) return;
    String message = 'Request failed (${response.statusCode})';
    try {
      final raw = response.error;
      final body = raw is String ? jsonDecode(raw) : raw;
      if (body is Map<String, dynamic>) {
        message = (body['detail'] as String?) ?? (body['title'] as String?) ?? message;
      }
    } catch (_) {}
    throw H3xBoardApiException(code: response.statusCode, message: message);
  }

}
