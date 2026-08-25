// Regenerates the bundled emoji artwork and metadata under assets/emoji/.
//
// Run with `just gen-emoji`. Everything under assets/emoji/ is generated — never
// hand-edit it. Re-run this after bumping [_notoTag] / [_cldrTag] to pick up a
// newer Unicode Emoji release.
//
// Why vector artwork instead of a color font: Flutter's Impeller renderer draws
// neither CBDT/CBLC bitmap tables nor COLRv1 vector tables, so a bundled emoji
// font renders as nothing at all on iOS/Android/macOS. Compiled vector_graphics
// (.vec) go through the ordinary canvas path and therefore look identical on
// every platform, including the web viewer and the external-display isolate.
//
// Pipeline:
//   1. fetch sources (Noto SVG artwork, Unicode emoji-test.txt, CLDR annotations)
//   2. parse emoji-test.txt for the canonical ordering, grouping and skin tones
//   3. compile each emoji's SVG to a half-precision .vec
//   4. emit index.json (order/groups/tones) and labels_<locale>.json (search)

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';
import 'package:xml/xml.dart';

// Pinned upstream sources. Bump these to adopt a newer Emoji release; the
// generator prints the versions it actually resolved so the bump is verifiable.
const _notoRepo = 'https://github.com/googlefonts/noto-emoji.git';
const _notoTag = 'v2.051';
const _cldrTag = 'release-48';

// Unicode publishes no per-version directory for Emoji 17.0 — /Public/emoji/
// stops at 16.0 and `latest/` is what serves 17.0 — so this URL cannot be
// pinned the way the other two sources are. [_expectedEmojiVersion] is the pin
// instead: the generator refuses to build against a spec it wasn't aimed at, so
// a silent upstream bump can't slip into a fresh clone unnoticed.
const _emojiTestUrl = 'https://unicode.org/Public/emoji/latest/emoji-test.txt';
const _expectedEmojiVersion = '17.0';

// The locales the picker can search in. Each needs a labels_<locale>.json; keep
// this in sync with the app's supported locales in l10n.yaml.
const _locales = ['en', 'nl'];

// Unicode's group names mapped to the stable ids used by the index and by the
// `emojiPicker_group*` ARB keys. "Component" is deliberately absent: it holds
// bare skin-tone and hair modifiers, which are never pickable on their own.
const _groupIds = {
  'Smileys & Emotion': 'smileysEmotion',
  'People & Body': 'peopleBody',
  'Animals & Nature': 'animalsNature',
  'Food & Drink': 'foodDrink',
  'Travel & Places': 'travelPlaces',
  'Activities': 'activities',
  'Objects': 'objects',
  'Symbols': 'symbols',
  'Flags': 'flags',
};

// The five Fitzpatrick skin-tone modifiers, in Unicode order.
const _skinTones = [0x1F3FB, 0x1F3FC, 0x1F3FD, 0x1F3FE, 0x1F3FF];

// Pack file names for those tones, in the same order. Must match the names of
// the toned values of `EmojiSkinTone` in lib/services/emoji/emoji_repository.dart,
// which is what the runtime builds its pack paths from.
const _toneNames = ['light', 'mediumLight', 'medium', 'mediumDark', 'dark'];

const _variationSelector = 0xFE0F;

// Where the app's own UI emoji are declared: every board widget descriptor's
// `String get emoji`, which the add-widget menu draws. Scanned rather than
// listed here so adding a widget cannot leave the pack behind — see [_uiEmojiKeys].
final _descriptorDir = Directory('lib/views/board_screen/components/widgets');
final _descriptorEmojiPattern = RegExp("String get emoji => '([^']+)';");

/// Name of the pack holding that artwork. Must match `UiEmojiPack._packName` in
/// lib/services/emoji/ui_emoji_pack.dart, which is what the app loads at startup.
const _uiPackName = 'ui';

final _sourcesDir = Directory('.dart_tool/emoji_sources');
final _outDir = Directory('assets/emoji');
final _vecDir = Directory('assets/emoji/vec');
final _packDir = Directory('assets/emoji/packs');

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  // The output is gitignored, so this runs as part of the default `just` setup.
  // Skipping when it is already current is what keeps that cheap.
  if (!force && _outputIsCurrent()) {
    stdout.writeln('assets/emoji/ is already current — pass --force to rebuild.');
    return;
  }

  await _ensureSources();

  // The masking/clipping/overdraw optimizers are what keep the compiled output
  // small; they need the native PathOps library out of the Flutter cache.
  if (!initializePathOpsFromFlutterCache()) {
    throw StateError('Could not initialize PathOps from the Flutter cache.');
  }

  final emojiTest = await File('${_sourcesDir.path}/emoji-test.txt').readAsString();
  final entries = _parseEmojiTest(emojiTest);
  final emojiVersion = _parseEmojiVersion(emojiTest);
  if (emojiVersion != _expectedEmojiVersion) {
    throw StateError(
      'emoji-test.txt is now Emoji $emojiVersion, but this generator is pinned to '
      '$_expectedEmojiVersion. Bump _expectedEmojiVersion (and probably _notoTag) '
      'after checking the artwork covers the new emoji.',
    );
  }
  stdout.writeln('Unicode Emoji $emojiVersion: ${entries.length} fully-qualified emoji');

  final artwork = _artworkSources();
  final groups = _buildGroups(entries, artwork);

  final compiled = await _compileArtwork(groups, artwork);
  await _writePacks(groups, compiled);
  await _writeIndex(groups, emojiVersion);
  for (final locale in _locales) {
    await _writeLabels(locale, groups);
  }

  stdout.writeln('Done. Rebuild with `just gen-emoji-force`.');
}

/// Whether assets/emoji/ was already built from exactly the pinned sources.
///
/// Compares the stamp [_writeIndex] leaves in index.json, so bumping any pinned
/// version invalidates the output automatically. Deliberately cheap: no network,
/// no hashing of 3.5k files — a partially-deleted output directory is a case for
/// `--force`, not something to detect on every build.
bool _outputIsCurrent() {
  final index = File('${_outDir.path}/index.json');
  if (!index.existsSync() || !_vecDir.existsSync()) return false;
  try {
    final stamp = jsonDecode(index.readAsStringSync()) as Map<String, dynamic>;
    final uiEmoji = (stamp['uiEmoji'] as List<dynamic>?)?.cast<String>();
    return stamp['emojiVersion'] == _expectedEmojiVersion &&
        stamp['notoVersion'] == _notoTag &&
        stamp['cldrVersion'] == _cldrTag &&
        // A new board widget adds an emoji here, which is what makes a plain
        // `just gen-emoji` rebuild the UI pack instead of no-opping.
        const ListEquality<String>().equals(uiEmoji, _uiEmojiKeys()) &&
        _locales.every((l) => File('${_outDir.path}/labels_$l.json').existsSync());
  } catch (_) {
    // A truncated or hand-edited index is not something to reason about.
    return false;
  }
}

/// The asset keys the app's own UI needs, read straight out of the board widget
/// descriptors that declare them (`String get emoji => '🎲';`).
///
/// Scanned rather than duplicated in a list here, and stamped into index.json by
/// [_writeIndex], so adding a widget invalidates the output and a plain
/// `just gen-emoji` rebuilds the pack. A hand-maintained list would silently ship
/// a menu row with no artwork the first time someone forgot to update it.
///
/// Returned sorted so the stamp is stable regardless of file order on disk.
List<String> _uiEmojiKeys() {
  if (!_descriptorDir.existsSync()) return const [];
  final keys = <String>{};
  for (final file in _descriptorDir.listSync()) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    for (final match in _descriptorEmojiPattern.allMatches(file.readAsStringSync())) {
      final emoji = match.group(1)!;
      keys.add(EmojiEntry.formatAssetKey(
        emoji.runes.where((cp) => cp != _variationSelector),
      ));
    }
  }
  return keys.toList()..sort();
}

// ---------------------------------------------------------------------------
// Sources
// ---------------------------------------------------------------------------

Future<void> _ensureSources() async {
  await _sourcesDir.create(recursive: true);

  final notoDir = Directory('${_sourcesDir.path}/noto-emoji');
  if (!notoDir.existsSync()) {
    stdout.writeln('Cloning Noto Emoji $_notoTag (artwork only)...');
    // A blobless sparse clone keeps this to the ~40 MB of SVG we actually need,
    // instead of the ~1 GB of PNG bitmaps the full repo carries.
    await _run('git', [
      'clone',
      '--depth', '1',
      '--branch', _notoTag,
      '--filter=blob:none',
      '--sparse',
      _notoRepo,
      notoDir.path,
    ]);
    // Country flags are not in svg/ — they are vendored separately under
    // third_party/region-flags, so both paths are needed for full coverage.
    await _run('git', ['sparse-checkout', 'set', 'svg', 'third_party/region-flags'], cwd: notoDir.path);
  }

  await _download(_emojiTestUrl, '${_sourcesDir.path}/emoji-test.txt');
  for (final locale in _locales) {
    // `annotations` carries the hand-authored names; `annotationsDerived` carries
    // the ones CLDR composes for sequences (families, flags, toned people).
    for (final kind in ['annotations', 'annotationsDerived']) {
      await _download(
        'https://raw.githubusercontent.com/unicode-org/cldr/$_cldrTag/common/$kind/$locale.xml',
        '${_sourcesDir.path}/${kind}_$locale.xml',
      );
    }
  }
}

Future<void> _download(String url, String path) async {
  final file = File(path);
  if (file.existsSync()) return;
  stdout.writeln('Downloading $url');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw StateError('GET $url failed with HTTP ${response.statusCode}');
    }
    await response.pipe(file.openWrite());
  } finally {
    client.close();
  }
}

Future<void> _run(String executable, List<String> args, {String? cwd}) async {
  final result = await Process.run(executable, args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    throw StateError('$executable ${args.join(' ')} failed:\n${result.stderr}');
  }
}

// ---------------------------------------------------------------------------
// emoji-test.txt
// ---------------------------------------------------------------------------

/// One fully-qualified emoji as listed by Unicode, in file order.
class EmojiEntry {

  final List<int> codePoints;
  final String group;

  const EmojiEntry({required this.codePoints, required this.group});

  /// The emoji as it should be stored and displayed, variation selectors included.
  String get emoji => String.fromCharCodes(codePoints);

  /// The artwork file name: code points minus variation selectors, lowercase hex,
  /// underscore-joined. Matches Noto's `emoji_u<seq>.svg` naming.
  ///
  /// Must stay byte-identical to `emojiAssetKey` in lib/services/emoji/emoji_repository.dart,
  /// which derives the same key at runtime straight from the emoji characters.
  String get assetKey => formatAssetKey(codePoints.where((cp) => cp != _variationSelector));

  /// The same sequence with every skin-tone modifier removed — the key under which
  /// a base emoji and all its toned variants collapse together.
  String get toneStrippedKey => formatAssetKey(
        codePoints.where((cp) => cp != _variationSelector && !_skinTones.contains(cp)),
      );

  /// Noto pads code points to at least four hex digits (`emoji_u0023_20e3.svg`),
  /// while leaving longer ones alone (`emoji_u1f600.svg`).
  static String formatAssetKey(Iterable<int> codePoints) =>
      codePoints.map((cp) => cp.toRadixString(16).padLeft(4, '0')).join('_');

  bool get hasTone => codePoints.any(_skinTones.contains);

}

List<EmojiEntry> _parseEmojiTest(String source) {
  final entries = <EmojiEntry>[];
  var group = '';

  for (final line in const LineSplitter().convert(source)) {
    if (line.startsWith('# group: ')) {
      group = line.substring('# group: '.length).trim();
      continue;
    }
    if (line.isEmpty || line.startsWith('#')) continue;

    // `1F44D 1F3FB ; fully-qualified # 👍🏻 E1.0 thumbs up: light skin tone`
    final semicolon = line.indexOf(';');
    final hash = line.indexOf('#');
    if (semicolon < 0 || hash < 0) continue;
    if (line.substring(semicolon + 1, hash).trim() != 'fully-qualified') continue;

    final codePoints = line
        .substring(0, semicolon)
        .trim()
        .split(RegExp(r'\s+'))
        .map((hex) => int.parse(hex, radix: 16))
        .toList();

    entries.add(EmojiEntry(codePoints: codePoints, group: group));
  }

  return entries;
}

String _parseEmojiVersion(String source) {
  final match = RegExp(r'^# Version: (.+)$', multiLine: true).firstMatch(source);
  return match?.group(1)?.trim() ?? 'unknown';
}

// ---------------------------------------------------------------------------
// Grouping
// ---------------------------------------------------------------------------

/// A base emoji plus the toned variants that have their own artwork.
class PickerEmoji {

  final EmojiEntry base;
  final List<EmojiEntry> tones;

  const PickerEmoji({required this.base, required this.tones});

}

/// One picker category, in Unicode order.
class PickerGroup {

  final String id;
  final List<PickerEmoji> emoji;

  const PickerGroup({required this.id, required this.emoji});

}

/// Collapses the flat Unicode list into picker groups: one row per base emoji,
/// carrying whichever uniformly-toned variants Noto actually ships artwork for.
///
/// Unicode also defines per-person tone combinations for multi-person sequences
/// (one light person holding hands with one dark person). Those are deliberately
/// dropped: the picker applies a single tone to a whole emoji, which is what the
/// tone selector can express.
List<PickerGroup> _buildGroups(List<EmojiEntry> entries, Map<String, File> artwork) {
  final tonesByBase = <String, List<EmojiEntry>>{};
  for (final entry in entries.where((e) => e.hasTone)) {
    // Only uniformly-toned sequences; a mixed-tone family has more than one.
    final used = entry.codePoints.where(_skinTones.contains).toSet();
    if (used.length != 1) continue;
    tonesByBase.putIfAbsent(entry.toneStrippedKey, () => []).add(entry);
  }

  final groups = <String, List<PickerEmoji>>{};
  final missing = <String>[];
  var missingTones = 0;

  for (final entry in entries) {
    if (entry.hasTone) continue;
    final groupId = _groupIds[entry.group];
    if (groupId == null) continue;

    if (!artwork.containsKey(entry.assetKey)) {
      missing.add('${entry.emoji} (${entry.assetKey})');
      continue;
    }

    final tones = <EmojiEntry>[];
    for (final tone in _skinTones) {
      final variant = tonesByBase[entry.toneStrippedKey]
          ?.where((e) => e.codePoints.contains(tone))
          .firstOrNull;
      if (variant == null || !artwork.containsKey(variant.assetKey)) continue;
      tones.add(variant);
    }
    // All five or none — a half-populated tone strip would look broken.
    if (tones.length != _skinTones.length) {
      if (tones.isNotEmpty) missingTones++;
      tones.clear();
    }

    groups.putIfAbsent(groupId, () => []).add(PickerEmoji(base: entry, tones: tones));
  }

  final ordered = _groupIds.values
      .where(groups.containsKey)
      .map((id) => PickerGroup(id: id, emoji: groups[id]!))
      .toList();

  final total = ordered.fold<int>(0, (sum, g) => sum + g.emoji.length);
  final toned = ordered.fold<int>(0, (sum, g) => sum + g.emoji.where((e) => e.tones.isNotEmpty).length);
  stdout.writeln('Picker: $total base emoji across ${ordered.length} groups, $toned with skin tones');
  if (missing.isNotEmpty) {
    // Named rather than counted: a silent gap here is indistinguishable from
    // full coverage, and upstream artwork does lag new Unicode releases.
    stdout.writeln('  skipped ${missing.length} without Noto artwork: ${missing.join(', ')}');
  }
  if (missingTones > 0) stdout.writeln('  dropped incomplete tone strips for $missingTones');

  return ordered;
}

/// Maps every asset key Noto ships artwork for to the file that draws it.
///
/// Both source directories already name their files `emoji_u<seq>.svg` using the
/// same code-point convention as [EmojiEntry.assetKey], so key lookup and file
/// lookup can never drift apart.
Map<String, File> _artworkSources() {
  const dirs = [
    'noto-emoji/svg',
    // Country and subdivision flags are vendored here rather than in svg/.
    // The waved variants are the ones the Noto emoji font itself ships.
    'noto-emoji/third_party/region-flags/waved-svg',
  ];

  final sources = <String, File>{};
  for (final dir in dirs) {
    final directory = Directory('${_sourcesDir.path}/$dir');
    if (!directory.existsSync()) continue;
    for (final file in directory.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.startsWith('emoji_u') || !name.endsWith('.svg')) continue;
      sources[name.substring('emoji_u'.length, name.length - '.svg'.length)] = file;
    }
  }
  return sources;
}

// ---------------------------------------------------------------------------
// Artwork
// ---------------------------------------------------------------------------

/// Compiles every emoji the picker offers to a `.vec`, returning the bytes so
/// [_writePacks] can bundle them without recompiling.
Future<Map<String, Uint8List>> _compileArtwork(
  List<PickerGroup> groups,
  Map<String, File> artwork,
) async {
  if (_vecDir.existsSync()) _vecDir.deleteSync(recursive: true);
  await _vecDir.create(recursive: true);

  final keys = <String>{};
  for (final group in groups) {
    for (final emoji in group.emoji) {
      keys
        ..add(emoji.base.assetKey)
        ..addAll(emoji.tones.map((t) => t.assetKey));
    }
  }

  final compiled = <String, Uint8List>{};
  for (final key in keys) {
    final xml = artwork[key]!.readAsStringSync();
    // Half precision roughly halves the payload. Emoji artwork is authored on a
    // small viewBox, so the lost precision is far below a pixel on screen.
    final vec = encodeSvg(
      xml: xml,
      debugName: key,
      useHalfPrecisionControlPoints: true,
    );
    File('${_vecDir.path}/$key.vec').writeAsBytesSync(vec);
    compiled[key] = vec;
  }

  final bytes = compiled.values.fold<int>(0, (sum, v) => sum + v.length);
  stdout.writeln('Compiled ${keys.length} .vec files (${(bytes / 1048576).toStringAsFixed(1)} MB)');
  return compiled;
}

/// Writes one pack per picker category, holding that category's base artwork.
///
/// The board draws a handful of emoji and wants the individual files — on web
/// each is a separate, tiny fetch. The picker shows hundreds at once, where that
/// same design costs ~1900 requests to browse the catalog. Packing per category
/// turns browsing everything into nine requests.
///
/// Skin-tone variants are deliberately left out. Including them more than
/// Skin tones get their own packs rather than riding along in the base one.
/// Folding them in more than doubles every pack — People & Body alone goes from
/// ~1.5 MB to ~9 MB, since 330 of its emoji carry five variants each — and every
/// visitor would pay for artwork only those who move the tone selector ever see.
/// Leaving them out entirely is worse: anyone with a tone selected then loads
/// hundreds of individual files, which is the problem packs exist to solve. So
/// `<group>.pack` holds the base artwork and `<group>.<tone>.pack` holds that
/// group's variants for one tone, fetched only while that tone is selected.
///
/// Layout (little-endian), a directory up front so one fetch yields both the
/// offsets and the data:
///
///   'EMPK', version:u8, entryCount:u32
///   entryCount × ( keyLength:u8, key:ascii, offset:u32, length:u32 )
///   artwork bytes, at the absolute offsets named above
///
/// Every offset is padded to a multiple of eight. The vector_graphics decoder
/// reads its payload through typed-data views up to Float64List, which throw
/// unless the byte offset divides by their element size — so an unpadded entry
/// parses and compares byte-identical yet still fails to draw. Costs a few bytes
/// per entry.
Future<void> _writePacks(List<PickerGroup> groups, Map<String, Uint8List> compiled) async {
  if (_packDir.existsSync()) _packDir.deleteSync(recursive: true);
  await _packDir.create(recursive: true);

  var total = 0;
  var count = 0;

  void writePack(String name, List<String> keys) {
    if (keys.isEmpty) return;

    // The directory's own size has to be known before offsets can be assigned,
    // so it is measured first and only then filled in.
    var directoryBytes = 4 + 1 + 4;
    for (final key in keys) {
      directoryBytes += 1 + key.length + 4 + 4;
    }

    // Offsets are assigned up front so the directory can name them, then the
    // data section is written with matching padding.
    final offsets = <String, int>{};
    var offset = _align8(directoryBytes);
    for (final key in keys) {
      offsets[key] = offset;
      offset = _align8(offset + compiled[key]!.length);
    }

    final builder = BytesBuilder(copy: false)
      ..add(ascii.encode('EMPK'))
      ..addByte(1)
      ..add(_u32(keys.length));

    for (final key in keys) {
      builder
        ..addByte(key.length)
        ..add(ascii.encode(key))
        ..add(_u32(offsets[key]!))
        ..add(_u32(compiled[key]!.length));
    }

    var written = directoryBytes;
    for (final key in keys) {
      builder
        ..add(Uint8List(offsets[key]! - written))
        ..add(compiled[key]!);
      written = offsets[key]! + compiled[key]!.length;
    }

    final bytes = builder.takeBytes();
    File('${_packDir.path}/$name.pack').writeAsBytesSync(bytes);
    total += bytes.length;
    count++;
  }

  // The app's own UI emoji, cutting the add-widget menu from one fetch per row
  // to one for the whole menu. Small enough (~19 entries) to preload at startup,
  // unlike the category packs, which are pulled only as the picker scrolls.
  final uiKeys = _uiEmojiKeys();
  final uncovered = uiKeys.where((key) => !compiled.containsKey(key)).toList();
  if (uncovered.isNotEmpty) {
    throw StateError(
      'Board widget descriptors declare emoji with no bundled artwork: '
      '${uncovered.join(', ')}. Pick an emoji the Noto set covers.',
    );
  }
  writePack(_uiPackName, uiKeys);

  for (final group in groups) {
    writePack(group.id, [for (final emoji in group.emoji) emoji.base.assetKey]);

    for (var tone = 0; tone < _toneNames.length; tone++) {
      writePack('${group.id}.${_toneNames[tone]}', [
        for (final emoji in group.emoji)
          if (emoji.tones.isNotEmpty) emoji.tones[tone].assetKey,
      ]);
    }
  }

  stdout.writeln('Packed $count packs (${(total / 1048576).toStringAsFixed(1)} MB)');
}

Uint8List _u32(int value) => Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

int _align8(int offset) => (offset + 7) & ~7;

// ---------------------------------------------------------------------------
// Index & labels
// ---------------------------------------------------------------------------

Future<void> _writeIndex(List<PickerGroup> groups, String emojiVersion) async {
  await _outDir.create(recursive: true);

  // Each emoji is an array: the base first, then its five toned variants when it
  // has them. Asset keys are derived at runtime from the characters themselves.
  final json = {
    'emojiVersion': emojiVersion,
    'notoVersion': _notoTag,
    'cldrVersion': _cldrTag,
    // Not read at runtime — this is the stamp [_outputIsCurrent] compares so a
    // newly added board widget rebuilds the UI pack on the next `just gen-emoji`.
    'uiEmoji': _uiEmojiKeys(),
    'groups': [
      for (final group in groups)
        {
          'id': group.id,
          'emoji': [
            for (final emoji in group.emoji) [emoji.base.emoji, ...emoji.tones.map((t) => t.emoji)],
          ],
        },
    ],
  };

  File('${_outDir.path}/index.json').writeAsStringSync(jsonEncode(json));
  stdout.writeln('Wrote index.json');
}

Future<void> _writeLabels(String locale, List<PickerGroup> groups) async {
  final names = <String, String>{};
  final keywords = <String, String>{};

  // annotationsDerived is read second so composed names win for sequences.
  for (final kind in ['annotations', 'annotationsDerived']) {
    final file = File('${_sourcesDir.path}/${kind}_$locale.xml');
    final document = XmlDocument.parse(file.readAsStringSync());
    for (final node in document.findAllElements('annotation')) {
      final cp = node.getAttribute('cp');
      if (cp == null) continue;
      if (node.getAttribute('type') == 'tts') {
        names[cp] = node.innerText.trim();
      } else {
        keywords[cp] = node.innerText.split('|').map((k) => k.trim()).join('|');
      }
    }
  }

  // Only the base emoji are searchable; picking a tone happens after the search.
  final labels = <String, List<String>>{};
  var unnamed = 0;
  for (final group in groups) {
    for (final emoji in group.emoji) {
      final key = emoji.base.emoji;
      // CLDR keys sequences without the variation selector about as often as with
      // it, so fall back to the stripped form before giving up.
      final stripped = String.fromCharCodes(
        emoji.base.codePoints.where((cp) => cp != _variationSelector),
      );
      final name = names[key] ?? names[stripped];
      final tags = keywords[key] ?? keywords[stripped] ?? '';
      if (name == null) {
        unnamed++;
        continue;
      }
      labels[key] = [name, tags];
    }
  }

  final output = File('${_outDir.path}/labels_$locale.json')..writeAsStringSync(jsonEncode(labels));
  final size = (output.lengthSync() / 1024).round();
  stdout.writeln('Wrote labels_$locale.json (${labels.length} entries, $size KB)'
      '${unnamed > 0 ? ', $unnamed without a CLDR name' : ''}');
}
