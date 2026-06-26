import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:h3xboard/models/api/file_summary.dart';

part 'browse_files_result.freezed.dart';
part 'browse_files_result.g.dart';

/// The contents of one virtual folder: the immediate sub-folder names and the
/// files directly in [path]. Returned by `files.v1.browse`.
@freezed
abstract class BrowseFilesResult with _$BrowseFilesResult {

  const factory BrowseFilesResult({
    required String path,
    required List<String> folders,
    required List<FileSummary> files,
  }) = _BrowseFilesResult;

  factory BrowseFilesResult.fromJson(Map<String, dynamic> json) => _$BrowseFilesResultFromJson(json);

}
