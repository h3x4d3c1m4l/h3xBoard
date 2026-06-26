import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/widgets/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The virtual folder shared background images are stored in. Decoupled from any
/// single board so an image uploaded once can be reused across boards.
const String backgroundsFolder = 'backgrounds';

/// The outcome of the [BackgroundPickerDialog]. A `null` [fileId] means the user
/// chose to remove the current background; the dialog returning `null` itself
/// (no result) means it was dismissed without a choice.
class BackgroundPickerResult {

  /// The selected file's id, or `null` to clear the background.
  final String? fileId;

  const BackgroundPickerResult(this.fileId);

}

/// Lets the user set a board's background image: pick one already uploaded, or
/// upload a new one. Browsing/deleting metadata go over the WebSocket API; the
/// bytes go over REST (see [H3xBoardFileService]).
class BackgroundPickerDialog extends StatefulWidget {

  final H3xBoardApiClient apiClient;
  final H3xBoardFileService fileService;
  final String? currentFileId;

  const BackgroundPickerDialog({
    super.key,
    required this.apiClient,
    required this.fileService,
    required this.currentFileId,
  });

  @override
  State<BackgroundPickerDialog> createState() => _BackgroundPickerDialogState();

}

class _BackgroundPickerDialogState extends State<BackgroundPickerDialog> {

  List<FileSummary>? _files;
  bool _loadError = false;
  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loadError = false;
      _files = null;
    });
    try {
      final result = await widget.apiClient.browseFiles(backgroundsFolder);
      final images = result.files.where((f) => f.contentType.startsWith('image/')).toList();
      if (!mounted) return;
      setState(() => _files = images);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

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
        path: backgroundsFolder,
      );
      if (!mounted) return;
      Navigator.of(context).pop(BackgroundPickerResult(summary.id));
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
        _errorMessage = context.localizations.backgroundPicker_uploadError;
      });
    }
  }

  void _select(String fileId) => Navigator.of(context).pop(BackgroundPickerResult(fileId));

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return ThemableContentDialog(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
      title: Text(loc.backgroundPicker_title),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: SizedBox(
          height: 360,
          child: _buildBody(loc),
        ),
      ),
      actions: [
        if (widget.currentFileId != null)
          Button(
            onPressed: _busy ? null : () => Navigator.of(context).pop(const BackgroundPickerResult(null)),
            child: Text(loc.backgroundPicker_remove),
          ),
        Button(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(loc.backgroundPicker_cancel),
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
              Text(loc.backgroundPicker_uploadNew),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations loc) {
    if (_loadError) {
      return _CenteredMessage(
        icon: LucideIcons.triangleAlert,
        message: loc.backgroundPicker_loadError,
        action: Button(onPressed: _loadFiles, child: Text(loc.backgroundPicker_retry)),
      );
    }

    final files = _files;
    if (files == null) {
      return const Center(child: ProgressRing());
    }

    if (files.isEmpty) {
      return _CenteredMessage(
        icon: LucideIcons.imageOff,
        message: loc.backgroundPicker_empty,
      );
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
          child: GridView.builder(
            padding: const EdgeInsets.only(right: 4),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return _BackgroundThumb(
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

/// One image tile in the picker grid.
class _BackgroundThumb extends StatelessWidget {

  final FileSummary file;
  final H3xBoardFileService fileService;
  final bool isSelected;
  final VoidCallback? onPressed;

  const _BackgroundThumb({
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
