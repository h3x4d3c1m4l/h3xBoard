import 'package:freezed_annotation/freezed_annotation.dart';

part 'storage_usage.freezed.dart';
part 'storage_usage.g.dart';

/// How much of the account's storage allowance is in use. Returned by
/// `files.v1.usage`. See the server's `docs/file-storage.md#per-user-quota`.
///
/// [usedBytes] counts **everything the account has stored**, including files the
/// file API does not list — board screenshots occupy real bytes but never appear
/// in `files.v1.browse`. So this number can exceed the total of every file the
/// user can see, and a usage bar must show the server's figure rather than
/// summing what it has listed.
///
/// [quotaBytes] is **null for an unlimited account**. The server omits the field
/// entirely in that case (the RPC connection drops nulls), so absent and
/// unlimited are the same thing here — there is no zero-means-unlimited sentinel
/// to decode on this side.
@freezed
abstract class StorageUsage with _$StorageUsage {

  const factory StorageUsage({
    required int usedBytes,
    int? quotaBytes,
  }) = _StorageUsage;

  const StorageUsage._();

  /// Whether the account has a ceiling at all. An unlimited account has nothing
  /// to draw a bar against, so the UI leaves it out rather than drawing an empty
  /// one.
  bool get isLimited => quotaBytes != null;

  /// How full the account is, 0..1, or null when unlimited. Clamped, because the
  /// server allows a bounded overshoot: its quota check and the insert are not
  /// one transaction, so two concurrent uploads can both pass and land the
  /// account slightly over its ceiling.
  double? get fraction {
    final quota = quotaBytes;
    if (quota == null || quota <= 0) return null;

    return (usedBytes / quota).clamp(0.0, 1.0);
  }

  factory StorageUsage.fromJson(Map<String, dynamic> json) => _$StorageUsageFromJson(json);

}
