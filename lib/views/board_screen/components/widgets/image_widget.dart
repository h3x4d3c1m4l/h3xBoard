import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/file_picker_dialog.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Renders an uploaded image by its file id. Falls back to a placeholder when no
/// image is chosen yet or the bytes can't be fetched/decoded.
class ImageWidget extends StatelessWidget {

  /// Fallback frame used until an image (with its intrinsic size) is chosen.
  static const Size naturalSize = Size(400, 300);

  final String fileId;
  final H3xBoardFileService fileService;

  const ImageWidget({super.key, required this.fileId, required this.fileService});

  @override
  Widget build(BuildContext context) {
    if (fileId.isEmpty) return const _ImagePlaceholder();

    return FutureBuilder<Uint8List>(
      future: fileService.downloadCached(fileId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _ImagePlaceholder(isError: true);
        final bytes = snapshot.data;
        if (bytes == null) return const Center(child: ProgressRing());
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          // The frame already matches the image's aspect ratio (see the
          // descriptor's naturalSize), so a corrupt file falls back cleanly.
          errorBuilder: (context, error, stackTrace) => const _ImagePlaceholder(isError: true),
        );
      },
    );
  }

}

/// Shown when an image widget has no picture yet, or its bytes failed to load.
class _ImagePlaceholder extends StatelessWidget {

  final bool isError;

  const _ImagePlaceholder({this.isError = false});

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x11000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33000000)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isError ? LucideIcons.imageOff : LucideIcons.image, size: 48, color: const Color(0x66000000)),
            const SizedBox(height: 12),
            Text(
              isError ? loc.image_loadError : loc.image_noImage,
              style: const TextStyle(color: Color(0x99000000), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

}

class ImageWidgetDescriptor extends BoardWidgetDescriptor {

  static const ImageWidgetDescriptor instance = ImageWidgetDescriptor._();
  const ImageWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.image;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_image;

  @override
  Size naturalSize(BoardWidgetConfig config) {
    final c = config as ImageConfig;
    final w = c.width;
    final h = c.height;
    if (w != null && h != null && w > 0 && h > 0) return Size(w, h);
    return ImageWidget.naturalSize;
  }

  @override
  BoardWidgetConfig get defaultConfig => const ImageConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as ImageConfig;
    return ImageWidget(fileId: c.fileId, fileService: GetIt.I<H3xBoardFileService>());
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as ImageConfig;
    final loc = context.localizations;
    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.image, size: 16),
        text: Text(c.fileId.isEmpty ? loc.imageSettingsMenu_choose : loc.imageSettingsMenu_replace),
        onPressed: () => _pickImage(context, c, onChange),
      ),
    ];
  }

  // Opens the shared file picker (starting in the images folder), then stores the
  // chosen file id together with the image's intrinsic size so the widget frames
  // at the correct aspect ratio.
  static Future<void> _pickImage(
    BuildContext context,
    ImageConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) async {
    final fileService = GetIt.I<H3xBoardFileService>();
    final result = await showDialog<FilePickerResult>(
      context: context,
      builder: (_) => FilePickerDialog(
        apiClient: GetIt.I<H3xBoardApiClient>(),
        fileService: fileService,
        initialFolder: imagesFolder,
        currentFileId: config.fileId.isEmpty ? null : config.fileId,
        title: context.localizations.imagePicker_title,
      ),
    );
    if (result == null) return;

    final fileId = result.fileId;
    if (fileId == null || fileId.isEmpty) {
      onChange(config.copyWith(fileId: '', width: null, height: null));
      return;
    }

    final intrinsic = await _intrinsicSize(fileService, fileId);
    final framed = intrinsic == null ? null : _framedSize(intrinsic);
    onChange(config.copyWith(fileId: fileId, width: framed?.width, height: framed?.height));
  }

  // Scales the image's intrinsic pixel size to fit within the default frame while
  // preserving aspect ratio, so the widget keeps a sensible footprint instead of
  // dropping a huge photo at full resolution onto the 1920×1080 canvas. The frame
  // then matches the image's aspect ratio exactly, so it fills without distortion.
  static Size _framedSize(Size image) {
    if (image.width <= 0 || image.height <= 0) return ImageWidget.naturalSize;
    final scale = math.min(
      ImageWidget.naturalSize.width / image.width,
      ImageWidget.naturalSize.height / image.height,
    );
    return Size(image.width * scale, image.height * scale);
  }

  static Future<Size?> _intrinsicSize(H3xBoardFileService fileService, String fileId) async {
    try {
      final bytes = await fileService.downloadCached(fileId);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

}
