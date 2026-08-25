import 'package:flutter/services.dart';
import 'package:h3xboard/services/emoji/emoji_pack_store.dart';
import 'package:h3xboard/services/emoji/emoji_repository.dart';
import 'package:vector_graphics/vector_graphics.dart';

/// The emoji the app's own chrome draws — today, the board widget descriptors'
/// [BoardWidgetDescriptor.emoji] shown in the add-widget menu.
///
/// Separate from [EmojiPackStore] because the two have opposite loading rules.
/// The picker's category packs are megabytes each and are pulled only as the
/// user scrolls to them; this one is a couple of dozen entries, is needed the
/// first time a menu opens, and would otherwise cost one fetch per row on web.
/// So it is loaded once at startup and then answers synchronously.
///
/// Registered as a GetIt singleton in `setupServices` and warmed there; nothing
/// waits on it, because [loaderFor] degrades to null and [EmojiImage] falls back
/// to the emoji's individual asset.
class UiEmojiPack {

  /// Must match `_uiPackName` in tool/generate_emoji_assets.dart, which writes it.
  static const _packName = 'ui';

  final AssetBundle bundle;

  EmojiPack? _pack;

  UiEmojiPack({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  /// Whether the pack arrived. Callers don't need to check — [loaderFor] already
  /// returns null until then — but tests do.
  bool get isLoaded => _pack != null;

  /// Reads the pack into memory. Safe to call more than once; a failure is
  /// swallowed, since every caller has a working fallback.
  Future<void> load() async {
    if (_pack != null) return;
    try {
      _pack = EmojiPack.parse(_packName, await bundle.load('assets/emoji/packs/$_packName.pack'));
    } catch (_) {
      // A missing or stale pack costs an extra fetch per emoji, not a broken UI.
      // `just gen-emoji` rebuilds it.
    }
  }

  /// A loader for [emoji] out of the packed artwork, or null when the pack has
  /// not arrived (or does not hold it — a widget added without re-running
  /// `just gen-emoji`). Both cases MUST be handled by falling back to the
  /// emoji's individual asset, which is what [EmojiImage] does for a null loader.
  BytesLoader? loaderFor(String emoji) => _pack?.loaderFor(emojiAssetKey(emoji));

}
