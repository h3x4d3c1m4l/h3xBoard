import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/services/emoji/emoji_pack_store.dart';
import 'package:h3xboard/services/emoji/emoji_repository.dart';
// The compat entry point rather than the plain one: it is the only public way
// to reach [RenderingStrategy.picture], which the board needs — see [isScaled].
import 'package:vector_graphics/vector_graphics_compat.dart';

/// Draws one emoji from the bundled Noto artwork, filling whatever box it is
/// given.
///
/// Shared by the board widget and the picker grid so both render an emoji the
/// same way — including the fallback, which matters most in the picker, where a
/// missing tile would otherwise read as a broken app.
class EmojiImage extends StatelessWidget {

  /// The emoji characters, skin-tone modifier included.
  final String emoji;

  /// Where to read the artwork from. Defaults to the emoji's own asset, which is
  /// what the board wants — one small file per emoji on the page. The picker
  /// passes a loader backed by a category pack instead, so a grid of hundreds
  /// costs one fetch rather than one per tile (see [EmojiPackStore]).
  final BytesLoader? loader;

  /// Whether this emoji gets scaled after layout, as it is on the board.
  ///
  /// The plain `VectorGraphic` constructor hardcodes [RenderingStrategy.raster]:
  /// it rasterizes to a bitmap the size of its layout box and reuses that from
  /// frame to frame. On the board, where the artwork lays out at its natural 220
  /// and is then scaled up, that means magnifying a 220px bitmap — vector
  /// artwork that goes soft exactly like a PNG would. Drawing it as a picture
  /// re-renders the paths at the final transform, so it stays sharp at any size.
  ///
  /// The picker keeps the raster path on purpose: its tiles are small and never
  /// scaled, and reusing one bitmap per tile is what keeps a grid of hundreds
  /// cheap to scroll.
  final bool isScaled;

  const EmojiImage({super.key, required this.emoji, this.loader, this.isScaled = false});

  @override
  Widget build(BuildContext context) {
    final bytes = loader ?? AssetBytesLoader(emojiAssetPath(emoji));

    if (isScaled) {
      return createCompatVectorGraphic(
        loader: bytes,
        strategy: RenderingStrategy.picture,
        fit: BoxFit.contain,
        semanticsLabel: emoji,
        errorBuilder: (context, error, stackTrace) => _EmojiTextFallback(emoji: emoji),
        placeholderBuilder: (context) => const SizedBox.shrink(),
      );
    }

    return VectorGraphic(
      loader: bytes,
      fit: BoxFit.contain,
      semanticsLabel: emoji,
      // A board saved against a newer emoji set can name artwork this build
      // doesn't ship; falling back to the characters keeps the meaning even when
      // the drawing is missing.
      errorBuilder: (context, error, stackTrace) => _EmojiTextFallback(emoji: emoji),
      // Nothing to show for the split second the bytes are being read. An empty
      // box avoids a flash of spinner on every board load and on every scroll of
      // the picker grid.
      placeholderBuilder: (context) => const SizedBox.shrink(),
    );
  }

}

/// Last-resort rendering when an emoji's artwork isn't in this build: the
/// characters themselves, drawn by whatever font the platform has.
class _EmojiTextFallback extends StatelessWidget {

  final String emoji;

  const _EmojiTextFallback({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Text(emoji, style: const TextStyle(fontSize: 96)),
    );
  }

}
