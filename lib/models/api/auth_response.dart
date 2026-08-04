import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_response.freezed.dart';
part 'auth_response.g.dart';

@freezed
abstract class AuthResponse with _$AuthResponse {

  const factory AuthResponse({
    required String userId,
    required String email,
    String? firstName,
    String? lastName,
    /// Whether the address has been confirmed. Absent on servers predating
    /// e-mail verification, where every account is effectively verified.
    @Default(true) bool emailVerified,
    /// The BCP-47 tag the server mails this user in, or null when unset.
    String? locale,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);

}
