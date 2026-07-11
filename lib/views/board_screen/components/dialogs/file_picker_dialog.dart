import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Virtual folders that file uploads are organised into. Decoupled from any single
/// board so an image uploaded once can be reused across boards and widgets.
const String backgroundsFolder = 'backgrounds';
const String imagesFolder = 'images';

/// The outcome of a [FilePickerDialog]. A `null` [fileId] means the user chose to
/// clear/remove the current selection (only offered when `allowRemove` is set);
/// the dialog returning `null` itself (no result) means it was dismissed without
/// a choice.
class FilePickerResult {

  /// The selected file's id, or `null` to clear the current selection.
  final String? fileId;

  const FilePickerResult(this.fileId);

}

/// A reusable image file browser. Starts in [initialFolder] but lets the user
/// navigate the whole virtual folder tree (so e.g. an image uploaded as a board
/// background can be picked for an image widget and vice versa). Uploads land in
/// the folder currently being browsed.
///
/// Browsing metadata goes over the WebSocket API; the bytes go over REST (see
/// [H3xBoardFileService]).
class FilePickerDialog extends StatefulWidget {

  final H3xBoardApiClient apiClient;
  final H3xBoardFileService fileService;

  /// The folder shown first. The user can still navigate up to the root and into
  /// sibling folders from here.
  final String initialFolder;

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
      final images = result.files.where((f) => f.contentType.startsWith('image/')).toList();
      final folders = [...result.folders]..sort();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _files = images;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  void _openFolder(String name) => _loadFolder(_path.isEmpty ? name : '$_path/$name');

  Future<void> _uploadNew() async {
    final picked = await FilePicker.pickFiles(type: FileType.image, withData: true);
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final summary = await widget.fileService.upload(
        bytes: bytes,
        fileName: file.name,
        contentType: _contentTypeForExtension(file.extension),
        path: _path,
      );
      if (!mounted) return;
      Navigator.of(context).pop(FilePickerResult(summary.id));
    } on H3xBoardApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = context.localizations.filePicker_uploadError;
      });
    }
  }

  void _select(String fileId) => Navigator.of(context).pop(FilePickerResult(fileId));

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return ThemableContentDialog(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: SizedBox(
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBreadcrumb(loc),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(loc)),
            ],
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
              ? _CenteredMessage(icon: LucideIcons.imageOff, message: loc.filePicker_empty)
              : GridView.builder(
                  padding: const EdgeInsets.only(right: 4),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    childAspectRatio: 16 / 9,
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
                    return _ImageThumb(
                      file: file,
                      fileService: widget.fileService,
                      isSelected: file.id == widget.currentFileId,
                      onPressed: _busy ? null : () => _select(file.id),
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
              color: states.isHovered ? theme.accentColor.withValues(alpha: 0.5) : theme.resources.controlStrokeColorDefault,
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

/// One image tile in the picker grid.
class _ImageThumb extends StatelessWidget {

  final FileSummary file;
  final H3xBoardFileService fileService;
  final bool isSelected;
  final VoidCallback? onPressed;

  const _ImageThumb({
    required this.file,
    required this.fileService,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? theme.accentColor
                  : (states.isHovered ? theme.accentColor.withValues(alpha: 0.5) : theme.resources.controlStrokeColorDefault),
              width: isSelected ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<Uint8List>(
            future: fileService.downloadCached(file.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const _ThumbError();
              final bytes = snapshot.data;
              if (bytes == null) {
                return const Center(child: SizedBox(width: 18, height: 18, child: ProgressRing(strokeWidth: 2)));
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                // A corrupt/unsupported file must not leak a raw decode error
                // into the grid; show the same placeholder as a failed fetch.
                errorBuilder: (context, error, stackTrace) => const _ThumbError(),
              );
            },
          ),
        );
      },
    );
  }

}

/// Placeholder shown in a grid tile when its image can't be fetched or decoded.
class _ThumbError extends StatelessWidget {

  const _ThumbError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x11000000),
      child: Center(child: Icon(LucideIcons.imageOff, size: 20)),
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

/// Maps a file extension to an image MIME type for the upload's content type
/// (file_picker does not surface the MIME). Falls back to a generic binary type.
String _contentTypeForExtension(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    case 'svg':
      return 'image/svg+xml';
    default:
      return 'application/octet-stream';
  }
}
