import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/services/audio/board_audio_engine.dart';
import 'package:h3xboard/services/audio/voice_watcher.dart';
import 'package:h3xboard/services/content_types.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/components/file_format.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Virtual folders that file uploads are organised into. Decoupled from any single
/// board so an image uploaded once can be reused across boards and widgets.
const String backgroundsFolder = 'backgrounds';
const String imagesFolder = 'images';
const String soundsFolder = 'sounds';

/// What the native "open file" dialog offers. Every platform reads a different
/// field of an [XTypeGroup]: extensions on Windows/Linux/macOS, MIME types on
/// Android and the web, uniform type identifiers on iOS/macOS. So all three are
/// filled in. All three have to agree with the extensions the matching
/// `*ContentTypeForName` recognises.
const _imageTypeGroup = XTypeGroup(
  label: 'Images',
  extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'],
  mimeTypes: ['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'image/bmp', 'image/svg+xml'],
  uniformTypeIdentifiers: ['public.image'],
);

/// Deliberately **not** `public.audio`, and deliberately without m4a/aac: this
/// list is what SoLoud can actually decode (dr_mp3, dr_wav, dr_flac, and Ogg
/// Vorbis). Offering a format the engine has no decoder for would let a file
/// upload cleanly and then refuse to make a sound, with nothing to point at.
const _audioTypeGroup = XTypeGroup(
  label: 'Sounds',
  extensions: ['mp3', 'wav', 'flac', 'ogg', 'oga'],
  mimeTypes: ['audio/mpeg', 'audio/wav', 'audio/x-wav', 'audio/flac', 'audio/ogg'],
  uniformTypeIdentifiers: ['public.mp3', 'com.microsoft.waveform-audio', 'org.xiph.flac', 'org.xiph.ogg-audio'],
);

/// Builds one file's tile in the picker grid. Every kind renders its files
/// differently: a picture wants a thumbnail, a sound wants a name you can read
/// and a button you can audition it with. Folders stay identical across kinds.
typedef FilePickerTileBuilder = Widget Function({
  required FileSummary file,
  required H3xBoardFileService fileService,
  required bool isSelected,
  required VoidCallback? onPressed,
});

/// What a [FilePickerDialog] is browsing for.
///
/// Everything that differs between kinds of file lives here. So the dialog holds
/// no knowledge of images or sounds, and adding a third kind means adding a
/// constant rather than editing the dialog.
///
/// The same value also drives desktop drops. Sharing it keeps "what the open
/// dialog offers" and "what a drop accepts" from drifting apart. The two were
/// the same list in two places before.
enum FilePickerKind {

  images(
    typeGroup: _imageTypeGroup,
    contentTypePrefix: 'image/',
    defaultFolder: imagesFolder,
    contentTypeForName: imageContentTypeForName,
    buildTile: _ImageThumb.new,
    maxTileExtent: 160,
    tileAspectRatio: 16 / 9,
    emptyIcon: LucideIcons.imageOff,
    emptyMessage: _emptyImages,
    dropHint: _dropImages,
  ),

  sounds(
    typeGroup: _audioTypeGroup,
    contentTypePrefix: 'audio/',
    defaultFolder: soundsFolder,
    contentTypeForName: audioContentTypeForName,
    buildTile: _SoundTile.new,
    maxTileExtent: 320,
    tileAspectRatio: 4.5,
    emptyIcon: LucideIcons.volumeOff,
    emptyMessage: _emptySounds,
    dropHint: _dropSounds,
  );

  /// What the native "open file" dialog offers.
  final XTypeGroup typeGroup;

  /// The `contentType` prefix a stored file must have to be listed.
  final String contentTypePrefix;

  /// The folder the picker opens in when a caller doesn't override it.
  final String defaultFolder;

  /// Maps a file name to the MIME type to upload it as, or null when the
  /// extension isn't one this kind accepts. Neither the native dialog nor a
  /// desktop drop reliably reports a MIME type, so the extension is the fallback
  /// for both.
  final String? Function(String name) contentTypeForName;

  final FilePickerTileBuilder buildTile;

  /// Grid geometry. Pictures tile as small landscape thumbnails; sounds read as
  /// wide, short rows, because a file name is the thing being scanned.
  final double maxTileExtent;
  final double tileAspectRatio;

  final IconData emptyIcon;
  final String Function(AppLocalizations) emptyMessage;
  final String Function(AppLocalizations) dropHint;

  const FilePickerKind({
    required this.typeGroup,
    required this.contentTypePrefix,
    required this.defaultFolder,
    required this.contentTypeForName,
    required this.buildTile,
    required this.maxTileExtent,
    required this.tileAspectRatio,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.dropHint,
  });

  /// The MIME type to upload a dropped [file] as, or `null` when this kind
  /// doesn't accept it. The browser fills in the dropped file's MIME type, so
  /// trust that first and fall back to the extension for the platforms (and edge
  /// cases) that don't.
  ///
  /// Shaped to be handed straight to `uploadDroppedFiles` as its
  /// `contentTypeFor`, which is why it is a method rather than a free function:
  /// a tear-off (`kind.droppedContentTypeFor`) is already the callback.
  String? droppedContentTypeFor(DropItem file) {
    final mimeType = file.mimeType;
    if (mimeType != null && mimeType.startsWith(contentTypePrefix)) return mimeType;

    return contentTypeForName(file.name);
  }

}

// Torn off into the const kinds above, which a closure literal could not be.
String _emptyImages(AppLocalizations loc) => loc.filePicker_emptyImages;
String _emptySounds(AppLocalizations loc) => loc.filePicker_emptySounds;
String _dropImages(AppLocalizations loc) => loc.filePicker_dropImagesHere;
String _dropSounds(AppLocalizations loc) => loc.filePicker_dropSoundsHere;

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
                  : (states.isHovered
                      ? theme.accentColor.withValues(alpha: 0.5)
                      : theme.resources.controlStrokeColorDefault),
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

/// One sound in the picker grid: name, size, and a button to audition it.
///
/// The preview is the whole point of this tile. Picking a sound by file name is
/// guesswork, and a soundboard is built by picking a lot of them in a row.
///
/// Duration is shown only **after** a preview has loaded the file, never on
/// first paint. There is no length in the stored metadata. So showing the length
/// up front would mean downloading and decoding every sound in the folder just
/// to open the picker. That is the same trap the emoji picker avoids by not
/// fetching artwork nobody is looking at.
class _SoundTile extends StatefulWidget {

  final FileSummary file;
  final H3xBoardFileService fileService;
  final bool isSelected;
  final VoidCallback? onPressed;

  const _SoundTile({
    required this.file,
    required this.fileService,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  State<_SoundTile> createState() => _SoundTileState();

}

class _SoundTileState extends State<_SoundTile> {

  SoundHandle? _handle;
  Duration? _duration;
  bool _isLoading = false;
  bool _failed = false;

  /// Puts the button back to "play" when the audition ends on its own. Without
  /// it a tile that finished playing still offers to stop a voice that is gone,
  /// which in a picker built for auditioning sounds in a row is the state the
  /// user spends the most time in.
  final _voiceWatcher = VoiceWatcher();

  @override
  void dispose() {
    _voiceWatcher.dispose();
    final handle = _handle;
    if (handle != null) unawaited(BoardAudioEngine.instance.stopAll([handle]));
    super.dispose();
  }

  Future<void> _togglePreview() async {
    final playing = _handle;
    if (playing != null) {
      _voiceWatcher.cancel();
      await BoardAudioEngine.instance.stopAll([playing]);
      if (mounted) setState(() => _handle = null);
      return;
    }

    setState(() {
      _isLoading = true;
      _failed = false;
    });

    final engine = BoardAudioEngine.instance;
    final source = await engine.source(widget.file.id, () => widget.fileService.downloadCached(widget.file.id));
    if (!mounted) return;
    if (source == null) {
      setState(() {
        _isLoading = false;
        _failed = true;
      });
      return;
    }

    final handle = await engine.play(source);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _failed = handle == null;
      _handle = handle;
      _duration = engine.lengthOf(source);
    });
    // The length is kept when the voice ends: once a preview has decoded the
    // file that number is the tile's most useful label, and it is what the tile
    // shows next to the size from here on.
    if (handle != null) {
      _voiceWatcher.watch(handle, () {
        if (mounted) setState(() => _handle = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isPlaying = _handle != null;

    return HoverButton(
      onPressed: widget.onPressed,
      builder: (context, states) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.only(left: 10, right: 4),
          decoration: BoxDecoration(
            color: theme.resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? theme.accentColor
                  : (states.isHovered
                      ? theme.accentColor.withValues(alpha: 0.5)
                      : theme.resources.controlStrokeColorDefault),
              width: widget.isSelected ? 3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(_failed ? LucideIcons.volumeOff : LucideIcons.audioLines, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body,
                    ),
                    Text(
                      _subtitle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption?.copyWith(color: theme.resources.textFillColorSecondary),
                    ),
                  ],
                ),
              ),
              // Its own button inside the tile: pressing it auditions the sound
              // without selecting it, so browsing a folder never commits.
              IconButton(
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
                    : Icon(isPlaying ? LucideIcons.square : LucideIcons.play, size: 16),
                onPressed: _isLoading ? null : () => unawaited(_togglePreview()),
              ),
            ],
          ),
        );
      },
    );
  }

  String _subtitle(BuildContext context) {
    final loc = context.localizations;
    if (_failed) return loc.soundPicker_previewFailed;
    final size = formatFileSize(widget.file.sizeBytes);
    final duration = _duration;
    return duration == null ? size : '${formatAudioDuration(duration)} · $size';
  }

}
