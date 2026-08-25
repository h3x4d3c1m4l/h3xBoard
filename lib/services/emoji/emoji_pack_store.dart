import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:h3xboard/services/emoji/emoji_repository.dart';
import 'package:vector_graphics/vector_graphics.dart';

/// Serves emoji artwork out of one packed file per category.
///
/// The board draws a handful of emoji and loads them individually — on web that
/// is a separate, tiny fetch each, which is exactly right for a viewer showing
/// three emoji. The picker shows hundreds, where the same approach costs one
/// request per tile (~1900 to browse the whole catalog). This reads a category's
/// artwork as a single asset instead, so browsing everything costs nine.
///
/// Packs are built by `just gen-emoji`; see `_writePacks` in
/// tool/generate_emoji_assets.dart for the layout this parses.
class EmojiPackStore extends ChangeNotifier {

  /// Where packs are read from. Taken from the enclosing [DefaultAssetBundle]
  /// rather than reaching for [rootBundle], so it resolves the same way
  /// [AssetBytesLoader] does and can be substituted in tests.
  final AssetBundle bundle;

  /// Keyed by pack name (`smileysEmotion`, `peopleBody.dark`, …).
  final Map<String, EmojiPack> _packs = {};
  final Set<String> _loading = {};
  final Set<String> _failed = {};
  bool _disposed = false;

  EmojiPackStore(this.bundle);

  /// Whether everything needed to draw [group] at [tone] has arrived. A pure
  /// query — it never starts a load, because the slivers build a probe child for
  /// every category to establish their geometry, so loading on first build would
  /// pull every pack the moment the picker opens. Callers ask [request] for the
  /// categories actually on screen.
  ///
  /// Tiles must wait for this rather than drawing from their individual assets
  /// in the meantime, or they would fire exactly the requests the packs exist to
  /// replace.
  bool isLoaded(EmojiGroup group, EmojiSkinTone tone) =>
      _packNames(group, tone).every((name) => _packs.containsKey(name) || _failed.contains(name));

  /// Starts loading whatever [group] needs at [tone], if not already loaded or
  /// in flight. Callers rebuild on [notifyListeners].
  void request(EmojiGroup group, EmojiSkinTone tone) {
    for (final name in _packNames(group, tone)) {
      if (!_packs.containsKey(name) && !_failed.contains(name)) _load(name);
    }
  }

  /// A loader for [emoji]'s artwork, or null when no loaded pack holds it.
  ///
  /// The toned pack is consulted first and the base pack second, because a
  /// category contains both emoji that take a tone and emoji that don't, and only
  /// the former appear in the toned pack.
  BytesLoader? loaderFor(EmojiGroup group, String emoji, EmojiSkinTone tone) {
    final key = emojiAssetKey(emoji);
    for (final name in _packNames(group, tone).reversed) {
      final loader = _packs[name]?.loaderFor(key);
      if (loader != null) return loader;
    }
    return null;
  }

  /// The packs needed to draw [group] at [tone]: its base artwork, plus the toned
  /// variants — but only for the categories that actually have toned emoji, since
  /// the generator writes no pack for the rest.
  static List<String> _packNames(EmojiGroup group, EmojiSkinTone tone) => [
        group.id.name,
        if (tone != EmojiSkinTone.none && group.hasSkinTones) '${group.id.name}.${tone.name}',
      ];

  Future<void> _load(String name) async {
    if (!_loading.add(name)) return;
    try {
      final bytes = await bundle.load('assets/emoji/packs/$name.pack');
      if (_disposed) return;
      _packs[name] = EmojiPack.parse(name, bytes);
    } catch (_) {
      // A category with no toned emoji has no toned pack, which is expected.
      // Anything else missing leaves those tiles blank rather than taking the
      // picker down; `just gen-emoji-force` rebuilds them.
      _failed.add(name);
    } finally {
      _loading.remove(name);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

}

/// One category's artwork, parsed from its pack file.
@immutable
class EmojiPack {

  static const _magic = 'EMPK';
  static const _supportedVersion = 1;

  /// The pack's file name, for diagnostics only — a category id
  /// (`peopleBody`, `flags.dark`) or the app's own `ui` pack.
  final String name;
  final ByteData _bytes;
  final Map<String, (int offset, int length)> _entries;

  const EmojiPack._(this.name, this._bytes, this._entries);

  /// Reads the directory at the head of [bytes]. Throws [FormatException] if the
  /// file isn't a pack this build understands.
  factory EmojiPack.parse(String name, ByteData bytes) {
    if (bytes.lengthInBytes < 9) throw const FormatException('Emoji pack is truncated');
    final magic = ascii.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, 4));
    if (magic != _magic) throw FormatException('Not an emoji pack: $magic');
    final version = bytes.getUint8(4);
    if (version != _supportedVersion) throw FormatException('Emoji pack version $version');

    final count = bytes.getUint32(5, Endian.little);
    final entries = <String, (int, int)>{};
    var cursor = 9;
    for (var i = 0; i < count; i++) {
      final keyLength = bytes.getUint8(cursor);
      cursor += 1;
      final key = ascii.decode(bytes.buffer.asUint8List(bytes.offsetInBytes + cursor, keyLength));
      cursor += keyLength;
      final offset = bytes.getUint32(cursor, Endian.little);
      final length = bytes.getUint32(cursor + 4, Endian.little);
      cursor += 8;
      entries[key] = (offset, length);
    }
    return EmojiPack._(name, bytes, entries);
  }

  /// Absolute byte offset of every entry, for the alignment test — the decoder
  /// throws on an unaligned entry, which no byte-level comparison can detect.
  @visibleForTesting
  Map<String, int> get debugOffsets =>
      {for (final e in _entries.entries) e.key: _bytes.offsetInBytes + e.value.$1};

  /// A loader for the artwork stored under [assetKey], or null when this pack
  /// doesn't hold it.
  BytesLoader? loaderFor(String assetKey) {
    final entry = _entries[assetKey];
    if (entry == null) return null;
    return _PackedBytesLoader(this, assetKey, entry.$1, entry.$2);
  }

  /// A view onto this pack's buffer — no copy, so a tile costs nothing to draw.
  ///
  /// The decoder reads its payload through typed-data views up to `Float64List`,
  /// which throw unless the view starts on an 8-byte boundary. The generator pads
  /// entry offsets for exactly this reason; the copy below only happens if the
  /// buffer the bundle handed us is itself misaligned, which would otherwise fail
  /// to draw at all.
  ByteData _slice(int offset, int length) {
    final absolute = _bytes.offsetInBytes + offset;
    if (absolute % 8 == 0) {
      return ByteData.sublistView(_bytes, offset, offset + length);
    }
    return ByteData.sublistView(
      Uint8List.fromList(_bytes.buffer.asUint8List(absolute, length)),
    );
  }

}

/// Hands [VectorGraphic] one emoji's bytes out of an already-loaded pack.
@immutable
class _PackedBytesLoader extends BytesLoader {

  final EmojiPack _pack;
  final String _assetKey;
  final int _offset;
  final int _length;

  const _PackedBytesLoader(this._pack, this._assetKey, this._offset, this._length);

  @override
  Future<ByteData> loadBytes(BuildContext? context) async => _pack._slice(_offset, _length);

  // vector_graphics caches decoded pictures against this, so two tiles showing
  // the same emoji from the same pack must compare equal.
  @override
  bool operator ==(Object other) =>
      other is _PackedBytesLoader && other._pack == _pack && other._assetKey == _assetKey;

  @override
  int get hashCode => Object.hash(_pack, _assetKey);

  @override
  String toString() => 'EmojiPack(${_pack.name})/$_assetKey';

}
