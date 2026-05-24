import 'package:freezed_annotation/freezed_annotation.dart';

part 'board_summary.freezed.dart';
part 'board_summary.g.dart';

@freezed
abstract class BoardSummary with _$BoardSummary {

  const factory BoardSummary({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _BoardSummary;

  factory BoardSummary.fromJson(Map<String, dynamic> json) => _$BoardSummaryFromJson(json);

}
