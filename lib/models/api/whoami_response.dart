import 'package:freezed_annotation/freezed_annotation.dart';

part 'whoami_response.freezed.dart';
part 'whoami_response.g.dart';

@freezed
abstract class WhoAmiResponse with _$WhoAmiResponse {

  const factory WhoAmiResponse({
    required String userId,
    required String email,
    String? firstName,
    String? lastName,
  }) = _WhoAmiResponse;

  factory WhoAmiResponse.fromJson(Map<String, dynamic> json) => _$WhoAmiResponseFromJson(json);

}
