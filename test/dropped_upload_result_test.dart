import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/views/components/dropped_upload.dart';

/// How a mixed drop is counted.
///
/// A drop of both kinds runs one upload pass per kind, and every pass is offered
/// every file. So each pass reports the files it doesn't recognise as skipped,
/// and a photo is "skipped" by the sounds pass through no fault of its own. Only
/// a file that *every* pass skipped was really unusable.
///
/// Getting this wrong is silent in both directions. Too high and a drop that
/// worked perfectly opens an error dialog. Too low and a file the user dropped
/// vanishes without a word.
void main() {
  FileSummary file(String id) => FileSummary(
        id: id,
        fileName: '$id.bin',
        path: 'images',
        contentType: 'image/png',
        sizeBytes: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

  DroppedUploadResult pass({List<String> uploaded = const [], int skipped = 0, int failed = 0}) =>
      DroppedUploadResult(
        uploaded: uploaded.map(file).toList(),
        skipped: skipped,
        failed: failed,
        serverMessage: null,
      );

  const empty = DroppedUploadResult(uploaded: [], skipped: 0, failed: 0, serverMessage: null);

  /// Runs the real fold: merge every pass, then reconcile once at the end.
  DroppedUploadResult drop(List<DroppedUploadResult> passes) {
    var total = empty;
    for (final p in passes) {
      total = mergeDropResults(total, p);
    }
    return reconcileDropSkips(total, kindCount: passes.length);
  }

  group('a drop of both kinds', () {
    test('one unusable file is reported, not swallowed', () {
      // The regression. Reconciling per merge divided an already-divided figure,
      // so a lone .txt came out as `1 ~/ 2 == 0` and the drop looked like it had
      // worked. Nothing else in the flow would have told the user.
      final result = drop([pass(skipped: 1), pass(skipped: 1)]);

      expect(result.skipped, 1);
      expect(result.hasProblems, isTrue);
    });

    test('a drop that worked perfectly reports nothing', () {
      // Three photos: taken by the images pass, skipped by the sounds pass.
      // Reporting three skips here would open an error dialog over a clean drop.
      final result = drop([
        pass(uploaded: ['a', 'b', 'c']),
        pass(skipped: 3),
      ]);

      expect(result.skipped, 0);
      expect(result.hasProblems, isFalse);
    });

    test('counts only the files no pass could use, alongside the ones that worked', () {
      // Two photos and one .txt. The images pass takes the photos and skips the
      // .txt; the sounds pass skips all three.
      final result = drop([
        pass(uploaded: ['a', 'b'], skipped: 1),
        pass(skipped: 3),
      ]);

      expect(result.skipped, 1);
      expect(result.uploaded, hasLength(2));
    });

    test('several unusable files are all counted', () {
      final result = drop([pass(skipped: 3), pass(skipped: 3)]);

      expect(result.skipped, 3);
    });

    test('failures are summed rather than reconciled, since each pass owns its own', () {
      final result = drop([pass(failed: 1), pass(failed: 2)]);

      expect(result.failed, 3);
      expect(result.hasProblems, isTrue);
    });
  });

  group('a drop onto a widget that takes one kind', () {
    test('leaves the count alone, because there is nothing to discount', () {
      final result = drop([pass(skipped: 2)]);

      expect(result.skipped, 2);
    });

    test('still reports a clean single-kind drop as clean', () {
      final result = drop([
        pass(uploaded: ['a']),
      ]);

      expect(result.skipped, 0);
      expect(result.hasProblems, isFalse);
    });
  });

  test('tooLarge and the server message survive the fold', () {
    var total = mergeDropResults(
      empty,
      const DroppedUploadResult(uploaded: [], skipped: 0, failed: 1, serverMessage: 'nope', tooLarge: true),
    );
    total = mergeDropResults(total, pass(skipped: 1));

    final result = reconcileDropSkips(total, kindCount: 2);

    expect(result.tooLarge, isTrue);
    expect(result.serverMessage, 'nope');
  });
}
