import 'package:freezed_annotation/freezed_annotation.dart';

part 'board_detail.freezed.dart';
part 'board_detail.g.dart';

@freezed
abstract class BoardDetail with _$BoardDetail {

  const factory BoardDetail({
    required String id,
    required String title,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _BoardDetail;

  factory BoardDetail.fromJson(Map<String, dynamic> json) => _$BoardDetailFromJson(json);

}
