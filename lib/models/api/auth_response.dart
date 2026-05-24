import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_response.freezed.dart';
part 'auth_response.g.dart';

@freezed
abstract class AuthResponse with _$AuthResponse {

  const factory AuthResponse({
    required String accessToken,
    required String refreshToken,
    required int accessTokenExpiresInSeconds,
    required int userId,
    required String username,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);

}
