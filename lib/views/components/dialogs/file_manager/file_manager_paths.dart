/// Path and selection arithmetic for the file manager.
///
/// Free functions rather than methods on the dialog's state, because this is the
/// part that is worth testing and a widget test cannot reach into `State`. The
/// repo has no mocking library, so anything with a rule in it lives out here
/// where a plain unit test can call it.
library;

/// Why a folder name cannot be used. The UI maps these to localized strings; the
/// rule itself is locale-independent, which is what keeps it testable.
enum FolderNameProblem {

  /// Blank, or nothing but whitespace.
  empty,

  /// Contains a path separator, so it would silently create a nested folder (or
  /// escape the current one) instead of the folder the user typed.
  invalidCharacters,

  /// A folder of that name is already in the folder being browsed.
  duplicate,

}

/// The full path of [name] inside [parent]. The root folder is the empty string,
/// so a child of the root is just its own name — never `/name`, which the server
/// would treat as a different folder from `name`.
String joinFolderPath(String parent, String name) => parent.isEmpty ? name : '$parent/$name';

/// The segments of [path], for a breadcrumb. The root ("") has none.
List<String> folderSegments(String path) => path.isEmpty ? const [] : path.split('/');

/// The last segment of [path] — what a folder is called, as opposed to where it
/// is. The root has no name of its own, so it comes back empty and the caller
/// substitutes its own "Home" label.
String folderDisplayName(String path) {
  final segments = folderSegments(path);
  return segments.isEmpty ? '' : segments.last;
}

/// Whether [name] can be used for a new folder alongside [siblings], or `null`
/// when it can.
///
/// [siblings] are folder *names*, not paths — the ones already listed in the
/// folder being browsed.
FolderNameProblem? folderNameProblem(String name, {required Iterable<String> siblings}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return FolderNameProblem.empty;
  if (trimmed.contains('/') || trimmed.contains(r'\')) return FolderNameProblem.invalidCharacters;
  if (siblings.any((s) => s.toLowerCase() == trimmed.toLowerCase())) return FolderNameProblem.duplicate;

  return null;
}

/// Where a file at [filePath] moves to when the folder [oldPrefix] is renamed to
/// [newPrefix].
///
/// Matching is **by whole segment**, not by string prefix. `images` and
/// `imagesOld` share five characters and nothing else, so renaming the first
/// must leave the second where it is. Getting this wrong scatters an unrelated
/// folder's files across the tree, and there is no folder API to undo it with.
///
/// A path that is not inside [oldPrefix] comes back unchanged, so a caller may
/// hand it every file it collected without filtering first.
String rewriteFolderPath(String filePath, {required String oldPrefix, required String newPrefix}) {
  if (filePath == oldPrefix) return newPrefix;
  if (!filePath.startsWith('$oldPrefix/')) return filePath;

  final suffix = filePath.substring(oldPrefix.length + 1);
  return newPrefix.isEmpty ? suffix : '$newPrefix/$suffix';
}

/// Whether [filePath] is [folderPath] or sits somewhere below it. The whole-
/// segment rule of [rewriteFolderPath] applies here for the same reason.
bool isInFolder(String filePath, String folderPath) =>
    folderPath.isEmpty || filePath == folderPath || filePath.startsWith('$folderPath/');

/// The ids from [ordered] between [anchorId] and [targetId] inclusive — a
/// shift-click range.
///
/// Direction-agnostic: dragging a selection upwards is the same gesture as
/// dragging it down. An id that is no longer in [ordered] (the list reloaded
/// under the selection) yields just [targetId], rather than an empty range that
/// would read as "the click did nothing".
List<String> idsInRange(List<String> ordered, String anchorId, String targetId) {
  final anchor = ordered.indexOf(anchorId);
  final target = ordered.indexOf(targetId);
  if (anchor < 0 || target < 0) return target < 0 ? const [] : [targetId];

  final start = anchor < target ? anchor : target;
  final end = anchor < target ? target : anchor;
  return ordered.sublist(start, end + 1);
}
