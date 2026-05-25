import 'package:freezed_annotation/freezed_annotation.dart';

part 'reconnect_token_response.freezed.dart';
part 'reconnect_token_response.g.dart';

@freezed
abstract class ReconnectTokenResponse with _$ReconnectTokenResponse {

  const factory ReconnectTokenResponse({
    required String reconnectToken,
  }) = _ReconnectTokenResponse;

  factory ReconnectTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$ReconnectTokenResponseFromJson(json);

}
