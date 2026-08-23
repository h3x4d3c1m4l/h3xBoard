import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/file_picker_kind.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:h3xboard/views/components/dropped_upload.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The outcome of a [FilePickerDialog]. A `null` [fileId] means the user chose to
/// clear/remove the current selection (only offered when `allowRemove` is set);
/// the dialog returning `null` itself (no result) means it was dismissed without
/// a choice.
class FilePickerResult {

  /// The selected file's id, or `null` to clear the current selection.
  final String? fileId;

  /// The chosen file's metadata, so a caller can name a widget after it without
  /// a second round trip to look the name up from the id. Null when clearing.
  final FileSummary? file;

  const FilePickerResult(this.fileId, {this.file});

}

/// A reusable file browser. Starts in [initialFolder] but lets the user navigate
/// the whole virtual folder tree. An image uploaded as a board background can
/// therefore be picked for an image widget, and vice versa. Uploads land in the
/// folder currently being browsed.
///
/// Browsing metadata goes over the WebSocket API; the bytes go over REST (see
/// [H3xBoardFileService]).
class FilePickerDialog extends StatefulWidget {

  final H3xBoardApiClient apiClient;
  final H3xBoardFileService fileService;

  /// The folder shown first. The user can still navigate up to the root and into
  /// sibling folders from here.
  final String initialFolder;

  /// What is being browsed for. Decides the type filter, the native open dialog,
  /// how a file is rendered in the grid, and the empty/drop wording.
  final FilePickerKind kind;

  /// The id of the currently selected file, highlighted in the grid.
  final String? currentFileId;

  /// Dialog title.
  final String title;

  /// When true, shows a button that pops a [FilePickerResult] with a `null`
  /// file id to clear the current selection.
  final bool allowRemove;

  const FilePickerDialog({
    super.key,
    required this.apiClient,
    required this.fileService,
    required this.initialFolder,
    this.kind = FilePickerKind.images,
    required this.currentFileId,
    required this.title,
    this.allowRemove = false,
  });

  @override
  State<FilePickerDialog> createState() => _FilePickerDialogState();

}

class _FilePickerDialogState extends State<FilePickerDialog> {

  late String _path;
  List<String>? _folders;
  List<FileSummary>? _files;
  bool _loadError = false;
  bool _busy = false;
  bool _dragging = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _path = widget.initialFolder;
    _loadFolder(_path);
  }

  List<String> get _segments => _path.isEmpty ? const [] : _path.split('/');

  Future<void> _loadFolder(String path) async {
    setState(() {
      _path = path;
      _loadError = false;
      _folders = null;
      _files = null;
      _errorMessage = null;
    });
    try {
      final result = await widget.apiClient.browseFiles(path);
      final matching = result.files.where((f) => f.contentType.startsWith(widget.kind.contentTypePrefix)).toList();
      final folders = [...result.folders]..sort();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _files = matching;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  void _openFolder(String name) => _loadFolder(_path.isEmpty ? name : '$_path/$name');

  Future<void> _uploadNew() async {
    final file = await openFile(acceptedTypeGroups: [widget.kind.typeGroup]);
    if (file == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final summary = await widget.fileService.upload(
        bytes: await file.readAsBytes(),
        fileName: file.name,
        contentType: widget.kind.contentTypeForName(file.name) ?? 'application/octet-stream',
        path: _path,
      );
      if (!mounted) return;
      Navigator.of(context).pop(FilePickerResult(summary.id, file: summary));
    } on H3xBoardApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = uploadErrorText(
          context.localizations,
          tooLarge: e.isPayloadTooLarge,
          quotaExceeded: e.isQuotaExceeded,
          serverMessage: e.message,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = context.localizations.filePicker_uploadError;
      });
    }
  }

  void _select(FileSummary file) => Navigator.of(context).pop(FilePickerResult(file.id, file: file));

  // Files dragged in from the desktop land in the folder currently being browsed
  // — the same destination the "Upload here…" button uses.
  Future<void> _onDrop(DropDoneDetails details) async {
    if (_busy) return;
    setState(() {
      _dragging = false;
      _busy = true;
      _errorMessage = null;
    });

    final result = await uploadDroppedFiles(
      contentTypeFor: widget.kind.droppedContentTypeFor,
      fileService: widget.fileService,
      files: details.files,
      path: _path,
    );
    if (!mounted) return;

    // A single dropped image behaves like picking one: it is selected and the
    // dialog closes. Several at once stay in the grid so the user can see them
    // all and choose, since only one can be returned.
    if (result.uploaded.length == 1 && !result.hasProblems) {
      final uploaded = result.uploaded.single;
      Navigator.of(context).pop(FilePickerResult(uploaded.id, file: uploaded));
      return;
    }

    // Refresh first: _loadFolder clears the error message, so setting it
    // afterwards is what keeps a partial failure ("3 uploaded, 1 too large")
    // visible next to the files that did make it.
    if (result.uploaded.isNotEmpty) await _loadFolder(_path);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _errorMessage = _dropErrorMessage(result);
    });
  }

  String? _dropErrorMessage(DroppedUploadResult result) {
    final loc = context.localizations;
    if (result.failed > 0) {
      return uploadErrorText(
        loc,
        tooLarge: result.tooLarge,
        quotaExceeded: result.quotaExceeded,
        serverMessage: result.serverMessage,
      );
    }
    if (result.skipped > 0) return loc.filePicker_dropSkipped;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return ThemableContentDialog(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
      scrollableContent: false,
      title: Text(widget.title),
      content: DropTarget(
        enable: !_busy,
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: _onDrop,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: SizedBox(
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBreadcrumb(loc),
                const SizedBox(height: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildBody(loc)),
                      if (_dragging) Positioned.fill(child: _DropHint(message: widget.kind.dropHint(loc))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.allowRemove && widget.currentFileId != null)
          Button(
            onPressed: _busy ? null : () => Navigator.of(context).pop(const FilePickerResult(null)),
            child: Text(loc.filePicker_remove),
          ),
        Button(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(loc.filePicker_cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _uploadNew,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              else
                const Icon(LucideIcons.upload, size: 16),
              const SizedBox(width: 8),
              Text(loc.filePicker_uploadHere),
            ],
          ),
        ),
      ],
    );
  }

  // A breadcrumb of clickable folder segments, so the user can jump back up the
  // tree. "Home" is the storage root ("").
  Widget _buildBreadcrumb(AppLocalizations loc) {
    final segments = _segments;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _crumb(loc.filePicker_home, () => _loadFolder('')),
        for (var i = 0; i < segments.length; i++) ...[
          const Icon(LucideIcons.chevronRight, size: 14),
          _crumb(segments[i], () => _loadFolder(segments.sublist(0, i + 1).join('/'))),
        ],
      ],
    );
  }

  Widget _crumb(String label, VoidCallback onPressed) => HyperlinkButton(
        onPressed: _busy ? null : onPressed,
        child: Text(label),
      );

  Widget _buildBody(AppLocalizations loc) {
    if (_loadError) {
      return _CenteredMessage(
        icon: LucideIcons.triangleAlert,
        message: loc.filePicker_loadError,
        action: Button(onPressed: () => _loadFolder(_path), child: Text(loc.filePicker_retry)),
      );
    }

    final folders = _folders;
    final files = _files;
    if (folders == null || files == null) {
      return const Center(child: ProgressRing());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InfoBar(
              title: Text(_errorMessage!),
              severity: InfoBarSeverity.error,
              onClose: () => setState(() => _errorMessage = null),
            ),
          ),
        Expanded(
          child: (folders.isEmpty && files.isEmpty)
              ? _CenteredMessage(icon: widget.kind.emptyIcon, message: widget.kind.emptyMessage(loc))
              : GridView.builder(
                  padding: const EdgeInsets.only(right: 4),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: widget.kind.maxTileExtent,
                    childAspectRatio: widget.kind.tileAspectRatio,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: folders.length + files.length,
                  itemBuilder: (context, index) {
                    if (index < folders.length) {
                      final name = folders[index];
                      return _FolderTile(
                        name: name,
                        onPressed: _busy ? null : () => _openFolder(name),
                      );
                    }
                    final file = files[index - folders.length];
                    return widget.kind.buildTile(
                      file: file,
                      fileService: widget.fileService,
                      isSelected: file.id == widget.currentFileId,
                      onPressed: _busy ? null : () => _select(file),
                    );
                  },
                ),
        ),
      ],
    );
  }

}

/// A navigable folder tile in the picker grid.
class _FolderTile extends StatelessWidget {

  final String name;
  final VoidCallback? onPressed;

  const _FolderTile({required this.name, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: theme.resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: states.isHovered
                  ? theme.accentColor.withValues(alpha: 0.5)
                  : theme.resources.controlStrokeColorDefault,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.folder, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

/// Overlay shown while files are being dragged over the dialog, covering the grid
/// so the drop destination (the folder being browsed) is unmistakable.
class _DropHint extends StatelessWidget {

  final String message;

  const _DropHint({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.accentColor, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.upload, size: 32, color: theme.accentColor),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: theme.typography.bodyStrong),
          ],
        ),
      ),
    );
  }

}

class _CenteredMessage extends StatelessWidget {

  final IconData icon;
  final String message;
  final Widget? action;

  const _CenteredMessage({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }

}
