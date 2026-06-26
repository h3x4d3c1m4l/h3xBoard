import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_summary.freezed.dart';
part 'file_summary.g.dart';

/// Metadata for a stored file — no bytes. Returned by `files.v1.browse` and the
/// REST upload. [path] is the virtual folder the file lives in (forward-slash
/// separated, "" = root); [fileName] is the leaf. Together they form the file's
/// logical address within the owner. See the server's `docs/file-storage.md`.
@freezed
abstract class FileSummary with _$FileSummary {

  const factory FileSummary({
    required String id,
    required String path,
    required String fileName,
    required String contentType,
    required int sizeBytes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _FileSummary;

  factory FileSummary.fromJson(Map<String, dynamic> json) => _$FileSummaryFromJson(json);

}
