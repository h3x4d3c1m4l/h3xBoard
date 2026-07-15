import 'package:freezed_annotation/freezed_annotation.dart';

part 'share_session_info.freezed.dart';
part 'share_session_info.g.dart';

/// The live-share session `sharing.v1.start` returns: the ephemeral code
/// viewers join with, and how many are currently watching (non-zero when an
/// existing session was resumed).
@freezed
abstract class ShareSessionInfo with _$ShareSessionInfo {

  const factory ShareSessionInfo({
    required String code,
    @Default(0) int viewerCount,
  }) = _ShareSessionInfo;

  factory ShareSessionInfo.fromJson(Map<String, dynamic> json) => _$ShareSessionInfoFromJson(json);

}
