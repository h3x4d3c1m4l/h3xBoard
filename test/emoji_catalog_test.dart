import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/services/emoji/emoji_repository.dart';

/// Guards the one contract that spans the emoji build: `just gen-emoji` names
/// the artwork files, and [emojiAssetKey] re-derives those names at runtime from
/// the characters alone. Nothing links the two but this rule, and a mismatch is
/// invisible until an emoji silently renders as a fallback.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('emojiAssetKey', () {
    test('drops variation selectors, which Noto leaves out of its file names', () {
      expect(emojiAssetKey('\u{2764}\u{FE0F}'), '2764');
      expect(emojiAssetKey('\u{1F3F3}\u{FE0F}\u{200D}\u{1F308}'), '1f3f3_200d_1f308');
    });

    test('pads short code points to four digits, as Noto does', () {
      expect(emojiAssetKey('\u{00A9}\u{FE0F}'), '00a9');
      expect(emojiAssetKey('\u{0031}\u{FE0F}\u{20E3}'), '0031_20e3');
    });

    test('keeps skin tones, ZWJ sequences and tag sequences intact', () {
      expect(emojiAssetKey('\u{1F44D}\u{1F3FF}'), '1f44d_1f3ff');
      expect(
        emojiAssetKey('\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}'),
        '1f468_200d_1f469_200d_1f467_200d_1f466',
      );
      expect(
        emojiAssetKey('\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}'),
        '1f3f4_e0067_e0062_e0073_e0063_e0074_e007f',
      );
    });
  });

  group('catalog', () {
    test('every emoji it offers has artwork in the bundle', () async {
      final catalog = await EmojiCatalog.load('en');
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final bundled = manifest.listAssets().toSet();

      final missing = <String>[];
      for (final group in catalog.groups) {
        for (final entry in group.emoji) {
          for (final emoji in [entry.emoji, ...entry.tones]) {
            if (!bundled.contains(emojiAssetPath(emoji))) missing.add(emoji);
          }
        }
      }

      expect(missing, isEmpty, reason: '${missing.length} emoji would render as a text fallback');
    });

    test('covers every Unicode group, in Unicode order', () async {
      final catalog = await EmojiCatalog.load('en');
      expect([for (final g in catalog.groups) g.id], EmojiGroupId.values);
      expect(catalog.emojiVersion, isNotEmpty);
    });

    test('names and searches in the requested language', () async {
      final english = await EmojiCatalog.load('en');
      final dutch = await EmojiCatalog.load('nl');

      String nameOf(EmojiCatalog catalog, String emoji) => catalog.groups
          .expand((g) => g.emoji)
          .firstWhere((e) => e.emoji == emoji)
          .name;

      expect(nameOf(english, '\u{1F600}'), 'grinning face');
      expect(nameOf(dutch, '\u{1F600}'), 'grijnzend gezicht');
      // A query that only matches in its own language must not match in the other.
      expect(dutch.search('grijnzend'), isNotEmpty);
      expect(english.search('grijnzend'), isEmpty);
    });

    test('ranks a name match above a keyword-only match', () async {
      final catalog = await EmojiCatalog.load('en');
      final results = catalog.search('rocket');
      expect(results.first.emoji, '\u{1F680}');
    });

    test('skin tones are all-or-nothing, and applying one keeps the base otherwise', () async {
      final catalog = await EmojiCatalog.load('en');
      final entries = catalog.groups.expand((g) => g.emoji).toList();

      for (final entry in entries) {
        expect(entry.tones.length, anyOf(0, 5), reason: '${entry.emoji} has a partial tone strip');
      }

      final toned = entries.firstWhere((e) => e.emoji == '\u{1F44D}');
      expect(toned.withTone(EmojiSkinTone.dark), '\u{1F44D}\u{1F3FF}');
      expect(toned.withTone(EmojiSkinTone.none), '\u{1F44D}');

      // An emoji without tones ignores the selection rather than breaking.
      final untoned = entries.firstWhere((e) => !e.supportsSkinTones);
      expect(untoned.withTone(EmojiSkinTone.dark), untoned.emoji);
    });
  });
}
