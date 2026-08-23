import 'dart:async';
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/services/audio/board_audio_engine.dart';
import 'package:h3xboard/services/audio/voice_watcher.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_entry.dart';
import 'package:h3xboard/views/components/file_format.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The right-hand pane of the file manager: what is selected, and what can be
/// done to it.
///
/// Three states, driven purely by how many rows are selected — nothing, one
/// (preview plus metadata), or several (a summary). The pane owns no data of its
/// own; it renders [selected] and reports intent through the callbacks, so the
/// dialog stays the single place where anything is mutated.
class FileManagerDetails extends StatefulWidget {

  final List<FileManagerEntry> selected;
  final H3xBoardFileService fileService;

  /// Null while an operation is running, which is what disables the actions.
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;

  const FileManagerDetails({
    super.key,
    required this.selected,
    required this.fileService,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  });

  @override
  State<FileManagerDetails> createState() => _FileManagerDetailsState();

}

class _FileManagerDetailsState extends State<FileManagerDetails> {

  SoundHandle? _handle;
  Duration? _duration;
  bool _isLoadingAudio = false;
  bool _previewFailed = false;

  /// Puts the button back to "play" when the preview ends on its own.
  final _voiceWatcher = VoiceWatcher();

  @override
  void didUpdateWidget(FileManagerDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Audio that keeps playing after its row is deselected has no visible stop
    // button left, so the only way to silence it would be to close the dialog.
    final previous = oldWidget.selected.length == 1 ? oldWidget.selected.single.selectionId : null;
    final current = widget.selected.length == 1 ? widget.selected.single.selectionId : null;
    if (previous != current) _resetPreview();
  }

  @override
  void dispose() {
    _voiceWatcher.dispose();
    final handle = _handle;
    if (handle != null) unawaited(BoardAudioEngine.instance.stopAll([handle]));
    super.dispose();
  }

  /// Everything about the preview goes, including the length — a different file
  /// is about to be shown and its length is not this one's.
  void _resetPreview() {
    _stopVoice();
    setState(() {
      _duration = null;
      _isLoadingAudio = false;
      _previewFailed = false;
    });
  }

  /// Silences the voice and puts the button back to "play", **keeping** the
  /// length. Once a preview has decoded the file the length is known, and it
  /// stays the more useful label than an instruction the user just followed.
  void _stopVoice() {
    _voiceWatcher.cancel();
    final handle = _handle;
    if (handle != null) unawaited(BoardAudioEngine.instance.stopAll([handle]));
    setState(() => _handle = null);
  }

  Future<void> _togglePreview(FileSummary file) async {
    if (_handle != null) {
      _stopVoice();
      return;
    }

    setState(() {
      _isLoadingAudio = true;
      _previewFailed = false;
    });

    final engine = BoardAudioEngine.instance;
    final source = await engine.source(file.id, () => widget.fileService.downloadCached(file.id));
    if (!mounted) return;
    if (source == null) {
      setState(() {
        _isLoadingAudio = false;
        _previewFailed = true;
      });
      return;
    }

    final handle = await engine.play(source);
    if (!mounted) return;
    setState(() {
      _isLoadingAudio = false;
      _previewFailed = handle == null;
      _handle = handle;
      _duration = engine.lengthOf(source);
    });
    if (handle != null) {
      _voiceWatcher.watch(handle, () {
        if (mounted) setState(() => _handle = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    if (widget.selected.isEmpty) {
      return _CenteredHint(icon: LucideIcons.mousePointerClick, message: loc.fileManager_selectAFile);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: widget.selected.length == 1 ? _buildSingle(widget.selected.single) : _buildMany(),
    );
  }

  Widget _buildSingle(FileManagerEntry entry) {
    final loc = context.localizations;
    final theme = FluentTheme.of(context);
    final file = entry is FileEntry ? entry.file : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildPreview(entry)),
        const SizedBox(height: 16),
        Text(entry.name, style: theme.typography.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        if (file == null)
          _MetaRow(label: loc.fileManager_type, value: loc.fileManager_folder)
        else ...[
          _MetaRow(label: loc.fileManager_type, value: file.contentType),
          _MetaRow(label: loc.fileManager_size, value: formatFileSize(file.sizeBytes)),
          _MetaRow(label: loc.fileManager_created, value: _formatDate(file.createdAt)),
          if (file.updatedAt != file.createdAt)
            _MetaRow(label: loc.fileManager_modified, value: _formatDate(file.updatedAt)),
        ],
        const SizedBox(height: 16),
        _buildActions(count: 1),
      ],
    );
  }

  Widget _buildMany() {
    final loc = context.localizations;
    final theme = FluentTheme.of(context);
    final totalBytes = widget.selected
        .whereType<FileEntry>()
        .fold<int>(0, (sum, entry) => sum + entry.file.sizeBytes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _CenteredHint(
            icon: LucideIcons.copyCheck,
            message: loc.fileManager_selectedCount(widget.selected.length),
          ),
        ),
        // Folders contribute no size of their own, so this is the size of the
        // files that were picked directly — not of everything a selected folder
        // contains. Counting a folder's contents would need a browse per folder
        // just to draw a label.
        if (totalBytes > 0)
          Text(
            formatFileSize(totalBytes),
            style: theme.typography.caption,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),
        _buildActions(count: widget.selected.length),
      ],
    );
  }

  Widget _buildActions({required int count}) {
    final loc = context.localizations;
    final destructive = context.appTheme.colors.destructive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (count == 1) ...[
          Button(onPressed: widget.onRename, child: Text(loc.fileManager_rename)),
          const SizedBox(height: 8),
        ],
        Button(
          onPressed: widget.onMove,
          child: Text(count == 1 ? loc.fileManager_move : loc.fileManager_moveCount(count)),
        ),
        const SizedBox(height: 8),
        Button(
          onPressed: widget.onDelete,
          child: Text(
            count == 1 ? loc.fileManager_delete : loc.fileManager_deleteCount(count),
            style: TextStyle(color: widget.onDelete == null ? null : destructive),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(FileManagerEntry entry) {
    final loc = context.localizations;
    final file = entry is FileEntry ? entry.file : null;

    if (file == null) return const _PreviewFrame(child: Icon(LucideIcons.folder, size: 48));

    if (file.contentType.startsWith('image/')) {
      return _PreviewFrame(
        child: FutureBuilder<Uint8List>(
          future: widget.fileService.downloadCached(file.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _CenteredHint(icon: LucideIcons.imageOff, message: loc.fileManager_previewFailed);
            final bytes = snapshot.data;
            if (bytes == null) return const Center(child: ProgressRing());

            return Padding(
              padding: const EdgeInsets.all(8),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (context, _, _) =>
                    _CenteredHint(icon: LucideIcons.imageOff, message: loc.fileManager_previewFailed),
              ),
            );
          },
        ),
      );
    }

    if (file.contentType.startsWith('audio/')) return _PreviewFrame(child: _buildAudioPreview(file));

    return const _PreviewFrame(child: Icon(LucideIcons.file, size: 48));
  }

  Widget _buildAudioPreview(FileSummary file) {
    final loc = context.localizations;
    final theme = FluentTheme.of(context);
    final isPlaying = _handle != null;
    final duration = _duration;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isLoadingAudio)
          const SizedBox(width: 32, height: 32, child: ProgressRing())
        else
          IconButton(
            icon: Icon(isPlaying ? LucideIcons.square : LucideIcons.play, size: 28),
            onPressed: () => unawaited(_togglePreview(file)),
          ),
        const SizedBox(height: 8),
        Text(
          _previewFailed
              ? loc.fileManager_previewFailed
              // The stored metadata carries no length, so it can only be shown
              // once a preview has decoded the file. Fetching every clip just to
              // label it would be the same trap the sound picker avoids.
              : duration == null
                  ? (isPlaying ? loc.fileManager_stop : loc.fileManager_play)
                  : formatAudioDuration(duration),
          style: theme.typography.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final locale = Localizations.localeOf(context).toString();

    return DateFormat.yMMMd(locale).add_Hm().format(date.toLocal());
  }

}

/// The fixed square the preview is drawn in, so the metadata below it doesn't
/// shift as images of different shapes are selected.
class _PreviewFrame extends StatelessWidget {

  final Widget child;

  const _PreviewFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(kControlCornerRadius),
          side: BorderSide(color: theme.resources.controlStrokeColorDefault),
        ),
      ),
      child: Center(child: child),
    );
  }

}

class _MetaRow extends StatelessWidget {

  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: theme.typography.caption?.copyWith(color: theme.resources.textFillColorSecondary),
            ),
          ),
          Expanded(child: Text(value, style: theme.typography.caption)),
        ],
      ),
    );
  }

}

class _CenteredHint extends StatelessWidget {

  final IconData icon;
  final String message;

  const _CenteredHint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: theme.resources.textFillColorSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.typography.caption?.copyWith(color: theme.resources.textFillColorSecondary),
            ),
          ],
        ),
      ),
    );
  }

}
