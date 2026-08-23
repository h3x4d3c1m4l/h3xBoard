import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/server_info.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/views/components/dropped_upload.dart';
import 'package:h3xboard/views/components/file_format.dart';

/// What the user is told when an upload is refused.
///
/// "Too large" is the one upload failure that can arrive from something other
/// than this app's server. A reverse proxy in front of it enforces a body limit
/// of its own. The proxy answers 413 with an HTML error page, carrying no
/// message this app can read. Recognising the status is what stands between the
/// user and "Request failed (413)" for the most ordinary mistake there is.
void main() {
  late AppLocalizations loc;

  setUpAll(() async => loc = await AppLocalizations.delegate.load(const Locale('en')));

  tearDown(() async {
    if (GetIt.I.isRegistered<ServerController>()) await GetIt.I.unregister<ServerController>();
  });

  group('isPayloadTooLarge', () {
    test('recognises a bare HTTP 413, which is all a proxy gives us', () {
      const error = H3xBoardApiException(code: 413, message: 'Request failed (413)');
      expect(error.isPayloadTooLarge, isTrue);
    });

    test('recognises the server\'s own RPC code', () {
      // RpcErrors.CodePayloadTooLarge on the server side.
      const error = H3xBoardApiException(code: 4013, message: 'File is too large');
      expect(error.isPayloadTooLarge, isTrue);
    });

    test('does not fire on unrelated failures', () {
      expect(const H3xBoardApiException(code: 404, message: 'x').isPayloadTooLarge, isFalse);
      expect(const H3xBoardApiException(code: 4022, message: 'x').isPayloadTooLarge, isFalse);
      expect(const H3xBoardApiException(code: 500, message: 'x').isPayloadTooLarge, isFalse);
    });
  });

  group('isQuotaExceeded', () {
    test('recognises HTTP 507 from the upload routes', () {
      const error = H3xBoardApiException(code: 507, message: 'Storage quota exceeded: 1 of 2 bytes used');
      expect(error.isQuotaExceeded, isTrue);
    });

    test('recognises the JSON-RPC 4507 twin', () {
      expect(const H3xBoardApiException(code: 4507, message: 'x').isQuotaExceeded, isTrue);
    });

    test('does not collide with "too large", which is a different problem entirely', () {
      const tooLarge = H3xBoardApiException(code: 413, message: 'x');
      expect(tooLarge.isQuotaExceeded, isFalse);
      const overQuota = H3xBoardApiException(code: 507, message: 'x');
      expect(overQuota.isPayloadTooLarge, isFalse);
    });
  });

  group('uploadErrorText', () {
    test('passes an ordinary failure through with the server\'s own wording', () {
      expect(
        uploadErrorText(loc, tooLarge: false, serverMessage: 'Path is invalid'),
        'Path is invalid',
      );
    });

    test('falls back to a generic message when the server said nothing', () {
      expect(uploadErrorText(loc, tooLarge: false), loc.filePicker_uploadError);
    });

    test('says the file is too large even when nothing readable came back', () {
      // The proxy case: an HTML error page leaves serverMessage as whatever the
      // status line produced, which is not something to show anyone.
      final message = uploadErrorText(loc, tooLarge: true, serverMessage: 'Request failed (413)');

      expect(message, isNot(contains('413')));
      expect(message, loc.filePicker_tooLarge);
    });

    test('names the limit when the server has advertised one', () {
      GetIt.I.registerSingleton<ServerController>(_FakeServerController(maxUploadBytes: 10 * 1024 * 1024));

      final message = uploadErrorText(loc, tooLarge: true);

      expect(message, contains('10.0 MB'));
      expect(message, loc.filePicker_tooLargeWithLimit(formatFileSize(10 * 1024 * 1024)));
    });

    test('quotes the limit in the same units the picker labels files with', () {
      // "3.4 MB" next to "the maximum is 10485760 bytes" helps nobody.
      GetIt.I.registerSingleton<ServerController>(_FakeServerController(maxUploadBytes: 25 * 1024 * 1024));

      expect(uploadErrorText(loc, tooLarge: true), contains('25.0 MB'));
    });

    test('stays useful when server info never arrived', () {
      // /api/v1/server/info is fetched in the background and can still be null.
      expect(uploadErrorText(loc, tooLarge: true), loc.filePicker_tooLarge);
    });
  });

  group('DroppedUploadResult', () {
    test('defaults to not-too-large, so existing failures read unchanged', () {
      const result = DroppedUploadResult(uploaded: [], skipped: 0, failed: 1, serverMessage: 'boom');
      expect(result.tooLarge, isFalse);
    });
  });

  group('uploadErrorText over quota', () {
    test('replaces the server\'s developer-facing byte count', () {
      // The 507 body always arrives (no proxy answers 507 for us), and that is
      // the problem: it reads "Storage quota exceeded: 1073741824 of 1073741824
      // bytes used, and this needs 4096 more".
      final message = uploadErrorText(
        loc,
        tooLarge: false,
        quotaExceeded: true,
        serverMessage: 'Storage quota exceeded: 1073741824 of 1073741824 bytes used, and this needs 4096 more',
      );

      expect(message, loc.filePicker_quotaExceeded);
      expect(message, isNot(contains('bytes')));
    });

    test('wins over the plain server-message fallback, which would leak it', () {
      expect(
        uploadErrorText(loc, tooLarge: false, quotaExceeded: true, serverMessage: 'anything'),
        isNot('anything'),
      );
    });

    test('a normal failure is unaffected', () {
      expect(uploadErrorText(loc, tooLarge: false, serverMessage: 'Path is invalid'), 'Path is invalid');
    });
  });

  group('formatFileSize', () {
    test('a quota-sized total reads in GB, not four digits of MB', () {
      expect(formatFileSize(1024 * 1024 * 1024), '1.0 GB');
      expect(formatFileSize(10 * 1024 * 1024 * 1024), '10.0 GB');
    });

    test('the units below it are unchanged, so file labels do not move', () {
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(2048), '2 KB');
      expect(formatFileSize(3 * 1024 * 1024), '3.0 MB');
    });
  });
}

/// A [ServerController] that only answers the one question this file asks.
///
/// Its constructor reaches for auth and settings services, so it is faked rather
/// than built — the notifier is the whole surface under test here.
class _FakeServerController implements ServerController {

  @override
  final ValueNotifier<ServerInfo?> serverInfo;

  _FakeServerController({required int maxUploadBytes})
      : serverInfo = ValueNotifier(ServerInfo(registrationAllowed: true, maxUploadBytes: maxUploadBytes));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

}
