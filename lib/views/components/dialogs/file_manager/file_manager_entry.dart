import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_paths.dart';

/// One row in the file manager: a folder or a file.
///
/// Both kinds share a [selectionId] so selection, shift-ranges and bulk actions
/// work over a single flat list. A folder has no id of its own — it exists only
/// as a path on the files inside it — so it borrows one, prefixed to keep it
/// from ever colliding with a real file id.
sealed class FileManagerEntry {

  const FileManagerEntry();

  /// Identifies this row within the folder being browsed. Stable for as long as
  /// the row is on screen, which is all a selection needs.
  String get selectionId;

  /// What the row is called.
  String get name;

}

/// A sub-folder of the folder being browsed.
class FolderEntry extends FileManagerEntry {

  /// The folder's full path, not just its name.
  final String path;

  /// Whether this folder exists only in this dialog because the user just
  /// created it.
  ///
  /// The server has no folder API: a folder is the `path` of the files in it, so
  /// an empty one cannot be stored. A pending folder is navigable and can be
  /// uploaded into — which is what makes it real — but it is gone on the next
  /// browse if it stayed empty. The UI says so rather than letting it silently
  /// disappear.
  final bool isPending;

  const FolderEntry(this.path, {this.isPending = false});

  @override
  String get selectionId => 'folder:$path';

  @override
  String get name => folderDisplayName(path);

}

/// A file in the folder being browsed.
class FileEntry extends FileManagerEntry {

  final FileSummary file;

  const FileEntry(this.file);

  @override
  String get selectionId => file.id;

  @override
  String get name => file.fileName;

}
