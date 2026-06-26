import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';

/// Renders an uploaded image as a board background. The bytes are fetched (and
/// memoized) through [H3xBoardFileService.downloadCached], so re-rendering on
/// every board rebuild does not re-hit the network.
///
/// [fallbackColor] is painted underneath the image (and on its own while the
/// download is in flight or if it fails), so the board never flashes empty.
/// [child] — the line overlay — is drawn on top of the image.
class BoardBackgroundImage extends StatelessWidget {

  final String fileId;
  final Color fallbackColor;
  final H3xBoardFileService fileService;
  final Widget child;

  const BoardBackgroundImage({
    super.key,
    required this.fileId,
    required this.fallbackColor,
    required this.fileService,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: fallbackColor,
      child: FutureBuilder<Uint8List>(
        // keyed by fileId so a changed background triggers a fresh download.
        future: fileService.downloadCached(fileId),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          // [child] (the 1920x1080 line overlay) is the only non-positioned
          // entry, so it gives the Stack an intrinsic size — the board lives
          // under an InteractiveViewer that hands down unbounded constraints, so
          // a StackFit.expand here would force an infinite size. The image fills
          // that intrinsic size via Positioned.fill, painted under the overlay.
          return Stack(
            children: [
              if (bytes != null)
                Positioned.fill(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    // On a decode failure, fall through to the fallback color
                    // (the ColoredBox underneath) rather than a broken-image box.
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              child,
            ],
          );
        },
      ),
    );
  }

}
