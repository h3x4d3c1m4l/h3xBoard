import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_info.freezed.dart';
part 'server_info.g.dart';

@freezed
abstract class ServerInfo with _$ServerInfo {

  const factory ServerInfo({
    required bool registrationAllowed,
    required int maxUploadBytes,
    String? warning,
    String? webAppUrl,
    /// Whether an unverified address blocks login on this server. Absent on
    /// servers predating e-mail verification, which never blocked anyone.
    @Default(false) bool emailVerificationRequired,
  }) = _ServerInfo;

  factory ServerInfo.fromJson(Map<String, dynamic> json) => _$ServerInfoFromJson(json);

}
