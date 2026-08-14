import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/services/emoji/emoji_pack_store.dart';
import 'package:h3xboard/services/emoji/emoji_repository.dart';
import 'package:h3xboard/views/board_screen/components/widgets/emoji_image.dart';

/// Guards the category packs: a binary format written by `just gen-emoji` and
/// parsed at runtime, holding a second copy of artwork that also ships as
/// individual files. Nothing but these tests would notice the two drifting apart
/// — a wrong offset renders the wrong emoji rather than failing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<EmojiPack> packFor(EmojiGroupId group) async =>
      EmojiPack.parse(group, await rootBundle.load('assets/emoji/packs/${group.name}.pack'));

  test('every category ships a parseable pack', () async {
    for (final group in EmojiGroupId.values) {
      final pack = await packFor(group);
      expect(pack.group, group);
    }
  });

  test('a pack holds the base artwork for every emoji in its category', () async {
    final catalog = await EmojiCatalog.load('en');

    for (final group in catalog.groups) {
      final pack = await packFor(group.id);
      final missing = [
        for (final entry in group.emoji)
          if (pack.loaderFor(emojiAssetKey(entry.emoji)) == null) entry.emoji,
      ];
      expect(missing, isEmpty, reason: '${group.id.name} pack is missing ${missing.length} emoji');
    }
  });

  test('packed bytes are byte-identical to the individual assets', () async {
    final catalog = await EmojiCatalog.load('en');

    for (final group in catalog.groups) {
      final pack = await packFor(group.id);
      for (final entry in group.emoji) {
        final loader = pack.loaderFor(emojiAssetKey(entry.emoji))!;
        final packed = await loader.loadBytes(null);
        final individual = await rootBundle.load(emojiAssetPath(entry.emoji));

        // Compared byte for byte rather than by length: an off-by-one offset in
        // the pack directory still yields the right length but the wrong drawing.
        expect(
          packed.buffer.asUint8List(packed.offsetInBytes, packed.lengthInBytes),
          individual.buffer.asUint8List(individual.offsetInBytes, individual.lengthInBytes),
          reason: '${entry.emoji} differs between its pack and its own asset',
        );
      }
    }
  });

  test('the base pack carries base artwork only, tones live in their own pack', () async {
    final catalog = await EmojiCatalog.load('en');
    final group = catalog.groups.firstWhere((g) => g.id == EmojiGroupId.peopleBody);
    final basePack = await packFor(group.id);
    final toned = group.emoji.firstWhere((e) => e.supportsSkinTones);

    expect(basePack.loaderFor(emojiAssetKey(toned.emoji)), isNotNull);
    expect(
      basePack.loaderFor(emojiAssetKey(toned.withTone(EmojiSkinTone.dark))),
      isNull,
      reason: 'toned artwork would more than double every base pack',
    );

    final tonePack = EmojiPack.parse(
      group.id,
      await rootBundle.load('assets/emoji/packs/${group.id.name}.dark.pack'),
    );
    expect(tonePack.loaderFor(emojiAssetKey(toned.withTone(EmojiSkinTone.dark))), isNotNull);
  });

  test('the store serves toned emoji from a pack, never from individual assets', () async {
    // The regression this exists for: with a tone selected, every tone-capable
    // emoji was falling back to its own asset — hundreds of requests on web,
    // which is exactly what packs are supposed to prevent.
    final catalog = await EmojiCatalog.load('en');
    final group = catalog.groups.firstWhere((g) => g.id == EmojiGroupId.peopleBody);
    final store = EmojiPackStore(rootBundle);
    addTearDown(store.dispose);

    for (final tone in EmojiSkinTone.values) {
      store.request(group, tone);
      // Two microtask-friendly waits: the base pack and the toned pack.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.isLoaded(group, tone), isTrue, reason: 'packs for $tone never became ready');

      final unresolved = [
        for (final entry in group.emoji)
          if (store.loaderFor(group, entry.withTone(tone), tone) == null) entry.emoji,
      ];
      expect(
        unresolved,
        isEmpty,
        reason: '${unresolved.length} emoji at $tone would fall back to individual assets',
      );
    }
  });

  test('loaders for the same emoji compare equal, so decoded pictures are reused', () async {
    final pack = await packFor(EmojiGroupId.smileysEmotion);
    final key = emojiAssetKey('\u{1F600}');
    expect(pack.loaderFor(key), pack.loaderFor(key));
    expect(pack.loaderFor(key).hashCode, pack.loaderFor(key).hashCode);
  });

  test('every entry starts 8-byte aligned, or it parses but will not draw', () async {
    // The decoder reads its payload through typed-data views up to Float64List.
    // An unaligned entry compares byte-identical to its asset and still throws on
    // decode, so the byte test above cannot catch this on its own.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final packs = manifest.listAssets().where((a) => a.endsWith('.pack'));
    expect(packs, isNotEmpty);

    for (final asset in packs) {
      final pack = EmojiPack.parse(EmojiGroupId.flags, await rootBundle.load(asset));
      final unaligned = pack.debugOffsets.entries.where((e) => e.value % 8 != 0).toList();
      expect(unaligned, isEmpty, reason: '$asset has ${unaligned.length} unaligned entries');
    }
  });

  testWidgets('artwork from a pack actually decodes and draws', (tester) async {
    final pack = await packFor(EmojiGroupId.smileysEmotion);
    final loader = pack.loaderFor(emojiAssetKey('\u{1F600}'))!;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 64, height: 64, child: EmojiImage(emoji: '\u{1F600}', loader: loader)),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  test('a foreign or truncated file is rejected rather than misread', () async {
    expect(
      () => EmojiPack.parse(EmojiGroupId.flags, ByteData(4)),
      throwsA(isA<FormatException>()),
    );
    final notAPack = Uint8List.fromList('NOPE'.codeUnits + List.filled(16, 0));
    expect(
      () => EmojiPack.parse(EmojiGroupId.flags, ByteData.sublistView(notAPack)),
      throwsA(isA<FormatException>()),
    );
  });
}
