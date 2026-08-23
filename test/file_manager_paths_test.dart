import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_paths.dart';

/// The file manager's path arithmetic. Worth its own tests because the server has
/// no folder API: a folder is only ever the `path` string on its files, so every
/// folder operation is a batch of path rewrites that nothing else validates.
void main() {
  group('joinFolderPath', () {
    test('a child of the root is just its own name', () {
      // A leading slash would be a *different* folder to the server, and one the
      // breadcrumb could never navigate back out of.
      expect(joinFolderPath('', 'images'), 'images');
    });

    test('nests below a parent', () {
      expect(joinFolderPath('images', 'holiday'), 'images/holiday');
      expect(joinFolderPath('images/holiday', '2026'), 'images/holiday/2026');
    });
  });

  group('folderSegments / folderDisplayName', () {
    test('the root has no segments and no name of its own', () {
      expect(folderSegments(''), isEmpty);
      expect(folderDisplayName(''), '');
    });

    test('a nested folder is named after its last segment', () {
      expect(folderSegments('images/holiday/2026'), ['images', 'holiday', '2026']);
      expect(folderDisplayName('images/holiday/2026'), '2026');
    });
  });

  group('folderNameProblem', () {
    test('accepts an ordinary name', () {
      expect(folderNameProblem('holiday', siblings: const ['images']), isNull);
    });

    test('rejects blank and whitespace-only names', () {
      expect(folderNameProblem('', siblings: const []), FolderNameProblem.empty);
      expect(folderNameProblem('   ', siblings: const []), FolderNameProblem.empty);
    });

    test('rejects separators, which would create a folder nobody asked for', () {
      expect(folderNameProblem('a/b', siblings: const []), FolderNameProblem.invalidCharacters);
      expect(folderNameProblem(r'a\b', siblings: const []), FolderNameProblem.invalidCharacters);
    });

    test('rejects a duplicate regardless of case', () {
      expect(folderNameProblem('Images', siblings: const ['images']), FolderNameProblem.duplicate);
    });

    test('compares the trimmed name, so " images" is still a duplicate', () {
      expect(folderNameProblem('  images  ', siblings: const ['images']), FolderNameProblem.duplicate);
    });
  });

  group('rewriteFolderPath', () {
    test('rewrites the folder itself', () {
      expect(rewriteFolderPath('images', oldPrefix: 'images', newPrefix: 'photos'), 'photos');
    });

    test('rewrites everything below it, keeping the suffix', () {
      expect(
        rewriteFolderPath('images/holiday/2026', oldPrefix: 'images', newPrefix: 'photos'),
        'photos/holiday/2026',
      );
    });

    test('leaves a sibling whose name merely starts with the prefix alone', () {
      // The bug this guards: a string-prefix match turns "imagesOld" into
      // "photosOld" and scatters an unrelated folder. There is no undo.
      expect(rewriteFolderPath('imagesOld', oldPrefix: 'images', newPrefix: 'photos'), 'imagesOld');
      expect(
        rewriteFolderPath('imagesOld/a', oldPrefix: 'images', newPrefix: 'photos'),
        'imagesOld/a',
      );
    });

    test('leaves an unrelated path alone, so callers need not filter first', () {
      expect(rewriteFolderPath('sounds/ding', oldPrefix: 'images', newPrefix: 'photos'), 'sounds/ding');
    });

    test('moving to the root drops the separator', () {
      expect(rewriteFolderPath('images/holiday', oldPrefix: 'images', newPrefix: ''), 'holiday');
    });
  });

  group('isInFolder', () {
    test('the root contains everything', () {
      expect(isInFolder('images/a', ''), isTrue);
      expect(isInFolder('', ''), isTrue);
    });

    test('matches the folder itself and its descendants', () {
      expect(isInFolder('images', 'images'), isTrue);
      expect(isInFolder('images/holiday', 'images'), isTrue);
    });

    test('does not match a sibling sharing a character prefix', () {
      expect(isInFolder('imagesOld', 'images'), isFalse);
    });
  });

  group('idsInRange', () {
    const ordered = ['a', 'b', 'c', 'd'];

    test('selects forwards, inclusive of both ends', () {
      expect(idsInRange(ordered, 'b', 'd'), ['b', 'c', 'd']);
    });

    test('selects backwards, because dragging up is the same gesture', () {
      expect(idsInRange(ordered, 'd', 'b'), ['b', 'c', 'd']);
    });

    test('an anchor equal to the target is a single row', () {
      expect(idsInRange(ordered, 'c', 'c'), ['c']);
    });

    test('a stale anchor still selects the clicked row, so the click is not a no-op', () {
      expect(idsInRange(ordered, 'gone', 'c'), ['c']);
    });

    test('a target that is gone selects nothing', () {
      expect(idsInRange(ordered, 'a', 'gone'), isEmpty);
    });
  });
}
