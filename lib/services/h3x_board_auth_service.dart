import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/auth_response.dart';
import 'package:h3xboard/models/api/server_info.dart';
import 'package:h3xboard/models/api/whoami_response.dart';
import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:h3xboard/services/credentialed_http_client_web.dart'
    if (dart.library.io) 'package:h3xboard/services/credentialed_http_client_io.dart';
import 'package:http/http.dart' show Client;

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

  @POST(path: '/api/v1/auth/verify-email')
  Future<Response> verifyEmail(@Body() Map<String, dynamic> body);

  @POST(path: '/api/v1/auth/resend-verification')
  Future<Response> resendVerification(@Body() Map<String, dynamic> body);

  @POST(path: '/api/v1/auth/forgot-password')
  Future<Response> forgotPassword(@Body() Map<String, dynamic> body);

  @POST(path: '/api/v1/auth/reset-password')
  Future<Response> resetPassword(@Body() Map<String, dynamic> body);

  @POST(path: '/api/v1/auth/change-password')
  Future<Response> changePassword(@Body() Map<String, dynamic> body);

  @POST(path: '/api/v1/auth/change-email')
  Future<Response> changeEmail(@Body() Map<String, dynamic> body);

  @POST(path: '/api/v1/auth/confirm-email-change')
  Future<Response> confirmEmailChange(@Body() Map<String, dynamic> body);

  @POST(path: '/api/v1/auth/locale')
  Future<Response> setLocale(@Body() Map<String, dynamic> body);

}

class H3xBoardAuthService {

  // The underlying HTTP client is reused across base-URL changes; only the
  // Chopper client (which captures the base URL) is rebuilt in [updateBaseUrl].
  final Client _httpClient;
  _H3xBoardAuthChopperService _service;

  H3xBoardAuthService._(this._service, this._httpClient);

  static H3xBoardAuthService create(String baseUrl, CookieStore cookieStore) {
    final httpClient = createCredentialedHttpClient(cookieStore);
    return H3xBoardAuthService._(_buildService(baseUrl, httpClient), httpClient);
  }

  static _H3xBoardAuthChopperService _buildService(String baseUrl, Client httpClient) {
    final chopperClient = ChopperClient(
      baseUrl: Uri.parse(baseUrl),
      client: httpClient,
      converter: JsonConverter(),
      services: [],
    );
    return _H3xBoardAuthChopperService._create(chopperClient);
  }

  /// Re-points this service at [baseUrl] for all subsequent requests.
  void updateBaseUrl(String baseUrl) {
    _service = _buildService(baseUrl, _httpClient);
  }

  Future<AuthResponse> login({required String email, required String password}) async {
    final response = await _service.login({'email': email, 'password': password});
    _requireSuccess(response);
    return AuthResponse.fromJson(response.body as Map<String, dynamic>);
  }

  /// Registers a new account. [locale] is the BCP-47 tag the app is currently
  /// displayed in; the server mails the verification link in that language
  /// instead of guessing from `Accept-Language`.
  ///
  /// When the server requires verification it deliberately does **not** set a
  /// session cookie here — check [AuthResponse.emailVerified] before assuming
  /// the user is signed in.
  Future<AuthResponse> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? locale,
  }) async {
    final response = await _service.register({
      'email': email,
      'password': password,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      if (locale != null && locale.isNotEmpty) 'locale': locale,
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

  /// Confirms a registration with the token from the verification e-mail. On
  /// success the server signs the user in (a session cookie comes back with the
  /// response), so the caller can go straight into the app.
  ///
  /// Throws with code 400 when the link is invalid or expired. Submitting the
  /// same token twice is *not* an error — mail scanners and double-clicks both
  /// come back 200.
  Future<AuthResponse> verifyEmail(String token) async {
    final response = await _service.verifyEmail({'token': token});
    _requireSuccess(response);
    return AuthResponse.fromJson(response.body as Map<String, dynamic>);
  }

  /// Asks for a fresh verification link. Answered identically for a known
  /// address, an unknown one and an already-verified one — there is nothing
  /// here to report back to the user beyond "we've sent it if it exists".
  Future<void> resendVerification(String email) async {
    _requireSuccess(await _service.resendVerification({'email': email}));
  }

  /// Starts a password reset. Like [resendVerification], the answer never
  /// reveals whether the account exists.
  Future<void> forgotPassword(String email) async {
    _requireSuccess(await _service.forgotPassword({'email': email}));
  }

  /// Completes a password reset with the token from the e-mail. Creates no
  /// session — the user signs in with the new password.
  ///
  /// Throws with code 400 when the token is invalid/expired *or* the password
  /// is under 8 characters; a too-short password does not burn the token, so
  /// the same link can be retried.
  Future<void> resetPassword({required String token, required String newPassword}) async {
    _requireSuccess(await _service.resetPassword({'token': token, 'newPassword': newPassword}));
  }

  /// Changes the signed-in user's password. The session stays valid.
  ///
  /// Throws with code 401 for a wrong current password, 400 when the new one is
  /// too short or identical to the current one.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    _requireSuccess(await _service.changePassword({
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }));
  }

  /// Starts an address change: a confirmation link goes to [newEmail] and the
  /// stored address only moves once that link is opened.
  ///
  /// Throws with code 401 for a wrong password, 409 when the address is already
  /// in use, 400 when it is already this account's address.
  Future<void> changeEmail({required String newEmail, required String currentPassword}) async {
    _requireSuccess(await _service.changeEmail({
      'newEmail': newEmail,
      'currentPassword': currentPassword,
    }));
  }

  /// Completes an address change with the token mailed to the new address.
  /// Anonymous by design — that mailbox may well be open in a browser that has
  /// never seen this server.
  ///
  /// Throws with code 400 when the token is invalid/expired, 409 when the
  /// address was taken in the meantime.
  Future<AuthResponse> confirmEmailChange(String token) async {
    final response = await _service.confirmEmailChange({'token': token});
    _requireSuccess(response);
    return AuthResponse.fromJson(response.body as Map<String, dynamic>);
  }

  /// Tells the server which language to mail this user in. Pass null (or an
  /// empty string) to clear the preference and let the server decide.
  Future<void> setLocale(String? locale) async {
    _requireSuccess(await _service.setLocale({'locale': locale}));
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
