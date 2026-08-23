import 'package:desktop_drop/desktop_drop.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/views/components/file_format.dart';

/// The outcome of [uploadDroppedFiles]. Callers render their own error UI, so
/// the failures are reported as counts plus the server's message (when it gave
/// one, e.g. "file too large") rather than as pre-formatted text.
class DroppedUploadResult {

  /// Metadata of the files that made it to the server, in drop order.
  final List<FileSummary> uploaded;

  /// Dropped entries that were never attempted: folders, and files whose type
  /// the caller's resolver doesn't accept.
  final int skipped;

  /// Uploads that were attempted but threw.
  final int failed;

  /// The first server-provided error message, or `null` when the failures (if
  /// any) were not server-reported.
  final String? serverMessage;

  /// Whether any file was refused for being too big. Tracked separately from
  /// [serverMessage] because the most likely source of that refusal is a reverse
  /// proxy. That proxy answers with an HTML error page carrying no message at all.
  final bool tooLarge;

  /// Whether any file was refused because the account is out of storage room.
  ///
  /// Tracked separately for the opposite reason to [tooLarge]: the server's 507
  /// *does* carry a message, but it is a developer-facing byte count
  /// ("… 1073741824 of 1073741824 bytes used …"), so it must not be shown as-is
  /// and must not be reached through the [serverMessage] fallback either.
  final bool quotaExceeded;

  const DroppedUploadResult({
    required this.uploaded,
    required this.skipped,
    required this.failed,
    required this.serverMessage,
    this.tooLarge = false,
    this.quotaExceeded = false,
  });

  bool get hasProblems => skipped > 0 || failed > 0;

}

/// Folds one pass's upload result into the running total.
///
/// Skips are summed raw. Reconciling them belongs to [reconcileDropSkips], once,
/// after every pass has run — see there for why it cannot happen here.
DroppedUploadResult mergeDropResults(DroppedUploadResult total, DroppedUploadResult next) {
  return DroppedUploadResult(
    uploaded: [...total.uploaded, ...next.uploaded],
    skipped: total.skipped + next.skipped,
    failed: total.failed + next.failed,
    serverMessage: total.serverMessage ?? next.serverMessage,
    tooLarge: total.tooLarge || next.tooLarge,
    quotaExceeded: total.quotaExceeded || next.quotaExceeded,
  );
}

/// Turns the raw sum of per-pass skips into the number of dropped files that
/// *no* pass could use.
///
/// With [kindCount] kinds accepted, every dropped file is offered to every pass.
/// So a photo counts as "skipped" by the sounds pass and vice versa. A file some
/// pass took was skipped by the other `kindCount - 1` of them. A file nobody
/// took was skipped by all [kindCount]. Discounting the first group leaves a
/// figure that divides evenly by the number of passes.
///
/// This runs once, on the finished total. Applying it per merge divides an
/// already-divided figure, and the remainder is what gets lost. That is why a
/// single unusable file among two passes used to report zero skips, leaving the
/// drop looking like it had worked.
DroppedUploadResult reconcileDropSkips(DroppedUploadResult total, {required int kindCount}) {
  if (kindCount < 2) return total;
  final takenByAPass = total.uploaded.length * (kindCount - 1);
  return DroppedUploadResult(
    uploaded: total.uploaded,
    skipped: ((total.skipped - takenByAPass) ~/ kindCount).clamp(0, total.skipped),
    failed: total.failed,
    serverMessage: total.serverMessage,
    tooLarge: total.tooLarge,
    quotaExceeded: total.quotaExceeded,
  );
}

/// The MIME type to upload a dropped file as, or `null` to skip it. Callers that
/// accept only one family of files (the picker) return `null` for the rest;
/// callers that accept anything (the file manager) never do.
typedef DroppedContentTypeResolver = String? Function(DropItem file);

/// Uploads every file among [files] that [contentTypeFor] accepts into the
/// virtual folder [path], skipping folders and anything it rejects. Shared by
/// the drop targets on the file picker, the board and the file manager, so they
/// agree on what counts as an acceptable file and how its content type is
/// derived.
///
/// The accept rule is a callback rather than a fixed list because the three
/// callers disagree about it: a picker takes one kind, the board takes the kinds
/// it can place, the file manager takes whatever the server will store.
///
/// Uploads run sequentially: dropping a dozen files should not open a dozen
/// concurrent multipart requests. One file failing does not abort the rest.
Future<DroppedUploadResult> uploadDroppedFiles({
  required DroppedContentTypeResolver contentTypeFor,
  required H3xBoardFileService fileService,
  required List<DropItem> files,
  required String path,
}) async {
  final uploaded = <FileSummary>[];
  var skipped = 0;
  var failed = 0;
  var tooLarge = false;
  var quotaExceeded = false;
  String? serverMessage;

  for (final file in files) {
    // A dropped folder arrives as a DropItemDirectory; there is nothing to upload.
    if (file is DropItemDirectory) {
      skipped++;
      continue;
    }
    final contentType = contentTypeFor(file);
    if (contentType == null) {
      skipped++;
      continue;
    }
    try {
      final bytes = await file.readAsBytes();
      uploaded.add(await fileService.upload(
        bytes: bytes,
        fileName: file.name,
        contentType: contentType,
        path: path,
      ));
    } on H3xBoardApiException catch (e) {
      // Surfaces the server's own wording where there is one.
      failed++;
      if (e.isPayloadTooLarge) tooLarge = true;
      if (e.isQuotaExceeded) quotaExceeded = true;
      serverMessage ??= e.message;
    } catch (_) {
      failed++;
    }
  }

  return DroppedUploadResult(
    uploaded: uploaded,
    skipped: skipped,
    failed: failed,
    serverMessage: serverMessage,
    tooLarge: tooLarge,
    quotaExceeded: quotaExceeded,
  );
}

/// What to tell the user when an upload fails.
///
/// Two of the failures get their own branch ahead of the server's own wording,
/// for opposite reasons.
///
/// **Too large** is the one failure a client must recognise from the **status
/// alone**. The server answers a bare 413 with no body. That is deliberate: a
/// reverse proxy in front of it enforces its own body limit and answers 413
/// first with an unparseable error page. Any friendly payload would therefore be
/// present only sometimes. Falling through to whatever the status line produced
/// would show "Request failed (413)" for the most ordinary mistake there is:
/// picking a file that is too big.
///
/// The limit comes from `/api/v1/server/info`, so the message can name it. It is
/// only the *server's* limit, though. A stricter proxy in front will still refuse
/// something this app just said was allowed. That is why the wording stays "the
/// server accepts up to X" rather than promising X will work.
///
/// **Out of storage** is the reverse: the 507 always carries a message, and the
/// message is the problem. It is a developer-facing byte count, so it is
/// replaced rather than shown — and it must be caught *before* the
/// [serverMessage] fallback, which would otherwise surface it verbatim. The
/// numbers belong in the file manager's usage bar, next to the files that can be
/// deleted to fix it.
String uploadErrorText(
  AppLocalizations loc, {
  required bool tooLarge,
  bool quotaExceeded = false,
  String? serverMessage,
}) {
  if (quotaExceeded) return loc.filePicker_quotaExceeded;
  if (!tooLarge) return serverMessage ?? loc.filePicker_uploadError;

  final limit = GetIt.I.isRegistered<ServerController>()
      ? GetIt.I<ServerController>().serverInfo.value?.maxUploadBytes
      : null;
  return limit == null
      ? loc.filePicker_tooLarge
      : loc.filePicker_tooLargeWithLimit(formatFileSize(limit));
}
