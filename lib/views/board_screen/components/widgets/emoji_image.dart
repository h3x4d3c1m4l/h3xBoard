import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/services/emoji/emoji_pack_store.dart';
import 'package:h3xboard/services/emoji/emoji_repository.dart';
import 'package:vector_graphics/vector_graphics.dart';

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

  const EmojiImage({super.key, required this.emoji, this.loader});

  @override
  Widget build(BuildContext context) {
    return VectorGraphic(
      loader: loader ?? AssetBytesLoader(emojiAssetPath(emoji)),
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
