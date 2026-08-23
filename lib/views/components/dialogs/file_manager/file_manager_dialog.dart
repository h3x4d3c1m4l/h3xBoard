import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/models/api/storage_usage.dart';
import 'package:h3xboard/services/audio/board_audio_engine.dart';
import 'package:h3xboard/services/content_types.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_breadcrumb.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_details.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_entry.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_folder_picker.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_list.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_paths.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_prompts.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_usage_bar.dart';
import 'package:h3xboard/views/components/dialogs/themable_panel_dialog.dart';
import 'package:h3xboard/views/components/dropped_upload.dart';
import 'package:h3xboard/views/components/file_format.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Opens the file manager. Used from the boards overview and from inside a
/// board, so both entry points share one code path.
///
/// [useRootNavigator] defaults to `true` (matching `showAppDialog`). Pass `false`
/// when opening from inside a flyout so the dialog lands on the same navigator
/// the flyout is dismissing on — otherwise a root-level barrier stacks over the
/// still-closing flyout and leaves it visible behind the dialog.
Future<void> showFileManagerDialog(BuildContext context, {bool useRootNavigator = true}) => showAppDialog<void>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: useRootNavigator,
      builder: (_) => const FileManagerDialog(),
    );

/// Manages the files a user has uploaded: browse, upload, rename, move, delete,
/// and preview.
///
/// Deliberately separate from `FilePickerDialog`. A picker answers "which file",
/// and every control it grows that isn't an answer to that question is in the
/// way. This is where the destructive verbs live.
///
/// **Folders here are virtual.** The server has no folder API; a folder is only
/// the `path` string on the files inside it. So creating one is a local promise
/// until a file lands in it, and renaming or deleting one is a batch of
/// per-file operations that can half-succeed. Both are reported rather than
/// hidden.
class FileManagerDialog extends StatefulWidget {

  const FileManagerDialog({super.key});

  @override
  State<FileManagerDialog> createState() => _FileManagerDialogState();

}

class _FileManagerDialogState extends State<FileManagerDialog> {

  final H3xBoardApiClient _apiClient = GetIt.I<H3xBoardApiClient>();
  final H3xBoardFileService _fileService = GetIt.I<H3xBoardFileService>();

  String _path = '';

  /// Null means "still loading" — the same sentinel the file picker uses, so
  /// there is no second flag that can disagree with the data.
  List<String>? _folders;
  List<FileSummary>? _files;

  final Set<String> _selectedIds = {};

  /// Where a shift-click measures its range from.
  String? _anchorId;

  /// Folders that exist only in this dialog: created, but still empty, so the
  /// server does not know about them yet. Keyed by full path.
  final Set<String> _pendingFolders = {};

  bool _loadError = false;
  bool _dragging = false;

  /// Blocks every mutating control while one operation runs. Acting on a
  /// selection that shifts under a running delete is how the wrong file goes.
  bool _busy = false;

  String? _errorMessage;
  String? _infoMessage;

  /// The account's storage usage, or null when it is not known — still loading,
  /// or a server that predates `files.v1.usage`. Both render as nothing rather
  /// than as a guess.
  StorageUsage? _usage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFolder(''));
    unawaited(_loadUsage());
  }

  /// Refreshed after every mutation, not on every navigation: browsing a folder
  /// cannot change how much is stored.
  ///
  /// A failure is swallowed on purpose. The quota is the server's feature, and
  /// an app talking to a build without it must still manage files — the bar
  /// simply does not appear.
  Future<void> _loadUsage() async {
    try {
      final usage = await _apiClient.getStorageUsage();
      if (mounted) setState(() => _usage = usage);
    } catch (_) {
      if (mounted) setState(() => _usage = null);
    }
  }

  // ---------------------------------------------------------------- loading

  Future<void> _loadFolder(String path) async {
    setState(() {
      _path = path;
      _folders = null;
      _files = null;
      _loadError = false;
      _errorMessage = null;
      _selectedIds.clear();
      _anchorId = null;
    });

    try {
      final result = await _apiClient.browseFiles(path);
      if (!mounted) return;
      setState(() {
        _folders = result.folders.toList()..sort(_byNameInsensitive);
        _files = result.files.toList()..sort((a, b) => _byNameInsensitive(a.fileName, b.fileName));
        // A pending folder that now has files came back from the server, so it
        // is no longer pending — drop it rather than listing it twice.
        _pendingFolders.removeWhere((p) => _folders!.contains(folderDisplayName(p)) && isInFolder(p, path));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  static int _byNameInsensitive(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

  /// The rows of the folder being browsed: folders first, then files, each
  /// alphabetical. Pending folders are merged in so a folder you just made is
  /// where you left it.
  List<FileManagerEntry> get _entries {
    final folders = _folders;
    final files = _files;
    if (folders == null || files == null) return const [];

    final pendingHere = _pendingFolders
        .where((p) => isInFolder(p, _path) && p != _path && folderSegments(p).length == folderSegments(_path).length + 1)
        .where((p) => !folders.contains(folderDisplayName(p)))
        .toList()
      ..sort(_byNameInsensitive);

    return [
      ...folders.map((name) => FolderEntry(joinFolderPath(_path, name))),
      ...pendingHere.map((path) => FolderEntry(path, isPending: true)),
      ...files.map(FileEntry.new),
    ];
  }

  List<FileManagerEntry> get _selectedEntries =>
      _entries.where((e) => _selectedIds.contains(e.selectionId)).toList();

  // -------------------------------------------------------------- selection

  void _onRowPressed(FileManagerEntry entry) {
    final keyboard = HardwareKeyboard.instance;
    final toggling = keyboard.isControlPressed || keyboard.isMetaPressed;
    final ranging = keyboard.isShiftPressed;

    if (ranging && _anchorId != null) {
      final ids = idsInRange(_entries.map((e) => e.selectionId).toList(), _anchorId!, entry.selectionId);
      setState(() => _selectedIds.addAll(ids));
      return;
    }
    if (toggling) {
      _onRowChecked(entry);
      return;
    }
    // A plain click on a folder is navigation, which is what a plain click on a
    // folder means everywhere else. Selecting one is the checkbox's job.
    if (entry is FolderEntry) {
      if (entry.isPending) {
        setState(() => _infoMessage = context.localizations.fileManager_pendingFolderHint);
      }
      unawaited(_loadFolder(entry.path));
      return;
    }

    setState(() {
      _selectedIds
        ..clear()
        ..add(entry.selectionId);
      _anchorId = entry.selectionId;
    });
  }

  void _onRowChecked(FileManagerEntry entry) {
    setState(() {
      if (!_selectedIds.remove(entry.selectionId)) _selectedIds.add(entry.selectionId);
      _anchorId = entry.selectionId;
    });
  }

  void _onSelectAllChanged(bool selected) {
    setState(() {
      _selectedIds.clear();
      if (selected) _selectedIds.addAll(_entries.map((e) => e.selectionId));
      _anchorId = null;
    });
  }

  // --------------------------------------------------------------- uploads

  Future<void> _uploadNew() async {
    // No type group: a file manager stores whatever the server accepts, unlike a
    // picker, which offers only what its widget can use.
    final picked = await openFiles();
    if (picked.isEmpty || !mounted) return;

    await _run((loc) async {
      var failed = 0;
      var tooLarge = false;
      var quotaExceeded = false;
      String? serverMessage;
      for (final file in picked) {
        try {
          await _fileService.upload(
            bytes: await file.readAsBytes(),
            fileName: file.name,
            contentType: contentTypeForFileName(file.name),
            path: _path,
          );
        } on H3xBoardApiException catch (e) {
          failed++;
          if (e.isPayloadTooLarge) tooLarge = true;
          if (e.isQuotaExceeded) quotaExceeded = true;
          serverMessage ??= e.message;
        } catch (_) {
          failed++;
        }
      }

      return failed == 0
          ? null
          : uploadErrorText(loc, tooLarge: tooLarge, quotaExceeded: quotaExceeded, serverMessage: serverMessage);
    });
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    if (_busy) return;
    setState(() => _dragging = false);

    await _run((loc) async {
      final result = await uploadDroppedFiles(
        contentTypeFor: (file) => file.mimeType ?? contentTypeForFileName(file.name),
        fileService: _fileService,
        files: details.files,
        path: _path,
      );

      return result.hasProblems
          ? uploadErrorText(
              loc,
              tooLarge: result.tooLarge,
              quotaExceeded: result.quotaExceeded,
              serverMessage: result.serverMessage,
            )
          : null;
    });
  }

  // --------------------------------------------------------------- actions

  Future<void> _renameEntry(FileManagerEntry entry) async {
    final loc = context.localizations;
    final isFolder = entry is FolderEntry;
    final siblings = _entries.whereType<FolderEntry>().map((e) => e.name).where((n) => n != entry.name);

    final name = await showNamePromptDialog(
      context,
      title: isFolder ? loc.fileManager_renameFolderTitle : loc.fileManager_renameFileTitle,
      initialValue: entry.name,
      confirmLabel: loc.fileManager_save,
      validate: isFolder ? folderNameValidator(siblings) : fileNameValidator,
    );
    if (name == null || !mounted) return;

    if (entry is FileEntry) {
      await _run((_) async {
        await _apiClient.updateFile(entry.file.id, fileName: name);

        return null;
      });
      return;
    }

    final folder = entry as FolderEntry;
    if (folder.isPending) {
      // Nothing is stored yet, so this rename is a local one.
      setState(() {
        _pendingFolders
          ..remove(folder.path)
          ..add(joinFolderPath(_path, name));
      });
      return;
    }
    await _rewriteFolder(folder.path, joinFolderPath(_path, name));
  }

  Future<void> _moveEntries(List<FileManagerEntry> entries) async {
    final blocked = entries.whereType<FolderEntry>().map((e) => e.path).toSet();
    final destination = await showFolderPickerDialog(
      context,
      apiClient: _apiClient,
      initialPath: _path,
      blockedPaths: blocked,
    );
    if (destination == null || destination == _path || !mounted) return;

    final folders = entries.whereType<FolderEntry>().toList();
    final files = entries.whereType<FileEntry>().toList();

    await _run((loc) async {
      var done = 0;
      var total = files.length;

      for (final entry in files) {
        try {
          await _apiClient.updateFile(entry.file.id, path: destination);
          done++;
        } catch (_) {
          // Counted by the shortfall below; one failure must not abort the rest.
        }
      }

      for (final folder in folders) {
        if (folder.isPending) {
          setState(() {
            _pendingFolders
              ..remove(folder.path)
              ..add(joinFolderPath(destination, folder.name));
          });
          continue;
        }
        final moved = await _rewritePaths(folder.path, joinFolderPath(destination, folder.name));
        done += moved.done;
        total += moved.total;
      }

      return done == total ? null : loc.fileManager_partialSuccess(done, total);
    });
  }

  Future<void> _deleteEntries(List<FileManagerEntry> entries) async {
    final loc = context.localizations;
    final folders = entries.whereType<FolderEntry>().toList();
    final files = entries.whereType<FileEntry>().map((e) => e.file).toList();

    // A folder's own files are not in `entries`, so they have to be collected
    // before the confirmation can honestly say how much is about to go.
    final doomed = <FileSummary>[...files];
    if (folders.any((f) => !f.isPending)) {
      setState(() => _busy = true);
      try {
        for (final folder in folders.where((f) => !f.isPending)) {
          doomed.addAll(await _collectSubtree(folder.path));
        }
      } catch (_) {
        if (mounted) setState(() => _errorMessage = loc.fileManager_actionFailed);

        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    if (!mounted) return;

    final size = formatFileSize(doomed.fold<int>(0, (sum, f) => sum + f.sizeBytes));
    final single = entries.length == 1 ? entries.single : null;
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: switch (single) {
        FolderEntry() => loc.fileManager_deleteFolderTitle,
        FileEntry() => loc.fileManager_deleteFileTitle,
        _ => loc.fileManager_deleteManyTitle,
      },
      message: switch (single) {
        final FolderEntry folder => loc.fileManager_deleteFolderMessage(folder.name, doomed.length, size),
        final FileEntry file => loc.fileManager_deleteFileMessage(file.name),
        _ => loc.fileManager_deleteManyMessage(doomed.length, size),
      },
    );
    if (!confirmed || !mounted) return;

    await _run((loc) async {
      var done = 0;
      for (final file in doomed) {
        try {
          await _apiClient.deleteFile(file.id);
          // The engine keeps a decoded copy keyed by file id. Left behind, it
          // would still play after the bytes are gone.
          await BoardAudioEngine.instance.release(file.id);
          done++;
        } catch (_) {
          // Reported as a shortfall below.
        }
      }
      setState(() => _pendingFolders.removeAll(folders.map((f) => f.path)));

      return done == doomed.length ? null : loc.fileManager_partialSuccess(done, doomed.length);
    });
  }

  Future<void> _createFolder() async {
    final loc = context.localizations;
    final name = await showNamePromptDialog(
      context,
      title: loc.fileManager_newFolderTitle,
      initialValue: '',
      confirmLabel: loc.fileManager_create,
      validate: folderNameValidator(_entries.whereType<FolderEntry>().map((e) => e.name)),
    );
    if (name == null || !mounted) return;

    setState(() {
      _pendingFolders.add(joinFolderPath(_path, name));
      _infoMessage = loc.fileManager_pendingFolderHint;
    });
  }

  // ------------------------------------------------------- folder rewrites

  /// Renames or moves a stored folder by rewriting the path of every file under
  /// it. Reports a shortfall rather than claiming success.
  Future<void> _rewriteFolder(String from, String to) async {
    await _run((loc) async {
      final result = await _rewritePaths(from, to);

      return result.done == result.total ? null : loc.fileManager_partialSuccess(result.done, result.total);
    });
  }

  Future<({int done, int total})> _rewritePaths(String from, String to) async {
    final files = await _collectSubtree(from);
    var done = 0;
    for (final file in files) {
      try {
        await _apiClient.updateFile(file.id, path: rewriteFolderPath(file.path, oldPrefix: from, newPrefix: to));
        done++;
      } catch (_) {
        // Reported by the caller as a shortfall.
      }
    }

    return (done: done, total: files.length);
  }

  /// Every file at or below [path]. Costs one browse per folder, which is why
  /// nothing calls it to draw a label — only to act.
  Future<List<FileSummary>> _collectSubtree(String path) async {
    final collected = <FileSummary>[];
    final queue = <String>[path];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final result = await _apiClient.browseFiles(current);
      collected.addAll(result.files);
      queue.addAll(result.folders.map((name) => joinFolderPath(current, name)));
    }

    return collected;
  }

  // --------------------------------------------------------------- running

  /// Runs one mutating operation: blocks the controls, reloads the folder
  /// afterwards, and shows whatever the operation returned as its error.
  ///
  /// The reload comes *before* the message is set, because reloading clears it —
  /// that ordering is what keeps a partial failure visible next to the files
  /// that did make it.
  Future<void> _run(Future<String?> Function(AppLocalizations loc) operation) async {
    final loc = context.localizations;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    String? message;
    try {
      message = await operation(loc);
    } on H3xBoardApiException catch (e) {
      message = e.message;
    } catch (_) {
      message = loc.fileManager_actionFailed;
    }

    if (!mounted) return;
    await _loadFolder(_path);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _errorMessage = message;
    });
    // After the folder, so a slow usage query never holds up the list the user
    // is waiting on.
    unawaited(_loadUsage());
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return ThemablePanelDialog(
      constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
      // Flexible, not bare: the actions row hands a plain child unbounded width,
      // so a long usage line would overflow the footer on a narrow screen
      // instead of ellipsizing.
      leftActions: [Flexible(child: FileManagerUsageBar(usage: _usage))],
      rightActions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.fileManager_close),
        ),
      ],
      content: SizedBox(
        height: 560,
        child: DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (details) => unawaited(_onDrop(details)),
          child: _buildContent(loc),
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations loc) {
    final theme = FluentTheme.of(context);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(loc),
            const SizedBox(height: 8),
            if (_errorMessage != null || _infoMessage != null) ...[
              InfoBar(
                title: Text(_errorMessage ?? _infoMessage!),
                severity: _errorMessage != null ? InfoBarSeverity.error : InfoBarSeverity.info,
                onClose: () => setState(() {
                  _errorMessage = null;
                  _infoMessage = null;
                }),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildList(loc)),
                  Container(width: 1, color: context.appTheme.dialogs.panelBorderColor),
                  SizedBox(
                    width: 300,
                    child: FileManagerDetails(
                      selected: _selectedEntries,
                      fileService: _fileService,
                      onRename: _busy || _selectedEntries.length != 1
                          ? null
                          : () => unawaited(_renameEntry(_selectedEntries.single)),
                      onMove: _busy || _selectedEntries.isEmpty
                          ? null
                          : () => unawaited(_moveEntries(_selectedEntries)),
                      onDelete: _busy || _selectedEntries.isEmpty
                          ? null
                          : () => unawaited(_deleteEntries(_selectedEntries)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_dragging)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: theme.accentColor.withValues(alpha: 0.12),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.upload, size: 32, color: theme.accentColor),
                      const SizedBox(height: 12),
                      Text(loc.fileManager_dropFilesHere, style: theme.typography.bodyStrong),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: theme.micaBackgroundColor.withValues(alpha: 0.6),
              child: const Center(child: ProgressRing()),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(AppLocalizations loc) {
    return Row(
      children: [
        Expanded(child: FileManagerBreadcrumb(path: _path, onNavigate: (path) => unawaited(_loadFolder(path)))),
        const SizedBox(width: 8),
        Button(
          onPressed: _busy ? null : () => unawaited(_createFolder()),
          child: Text(loc.fileManager_newFolder),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _busy ? null : () => unawaited(_uploadNew()),
          child: Text(loc.fileManager_upload),
        ),
      ],
    );
  }

  Widget _buildList(AppLocalizations loc) {
    if (_loadError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.triangleAlert, size: 28),
            const SizedBox(height: 12),
            Text(loc.fileManager_loadError),
            const SizedBox(height: 12),
            Button(onPressed: () => unawaited(_loadFolder(_path)), child: Text(loc.fileManager_retry)),
          ],
        ),
      );
    }
    if (_folders == null || _files == null) return const Center(child: ProgressRing());

    final entries = _entries;
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.folderOpen, size: 28),
              const SizedBox(height: 12),
              Text(loc.fileManager_empty, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return FileManagerList(
      entries: entries,
      selectedIds: _selectedIds,
      enabled: !_busy,
      onRowPressed: _onRowPressed,
      onRowChecked: _onRowChecked,
      onSelectAllChanged: _busy ? null : _onSelectAllChanged,
      onRowAction: (entry, action) {
        switch (action) {
          case FileManagerRowAction.rename:
            unawaited(_renameEntry(entry));
          case FileManagerRowAction.move:
            unawaited(_moveEntries([entry]));
          case FileManagerRowAction.delete:
            unawaited(_deleteEntries([entry]));
        }
      },
    );
  }

}
