import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_info.freezed.dart';
part 'server_info.g.dart';

@freezed
abstract class ServerInfo with _$ServerInfo {

  const factory ServerInfo({
    required bool registrationAllowed,
    required int maxUploadBytes,
  }) = _ServerInfo;

  factory ServerInfo.fromJson(Map<String, dynamic> json) => _$ServerInfoFromJson(json);

}
