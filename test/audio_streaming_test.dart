import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/audio/board_audio_engine.dart';
import 'package:h3xboard/services/board_asset_resolver.dart';

/// The decision of *whether* to stream a track, which is the part that has to be
/// right before any audio is involved.
///
/// SoLoud can decode more formats from a complete file than it can sniff out of
/// a partial stream. Getting the decision wrong therefore does not fail loudly.
/// The wrong answer hands the engine a container it cannot identify from the
/// first chunk, and the track silently never starts.
void main() {
  group('canStream', () {
    test('accepts the containers SoLoud can sniff mid-stream', () {
      expect(BoardAudioEngine.canStream('audio/mpeg'), isTrue);
      expect(BoardAudioEngine.canStream('audio/ogg'), isTrue);
    });

    test('refuses WAV and FLAC, which only decode from a complete file', () {
      // Both play perfectly well — just through the whole-file loader. Streaming
      // them would produce a player that starts and stays silent.
      expect(BoardAudioEngine.canStream('audio/wav'), isFalse);
      expect(BoardAudioEngine.canStream('audio/flac'), isFalse);
    });

    test('refuses an unknown or absent type', () {
      // Null is what a player configured before contentType was recorded has;
      // it must take the whole-file path rather than gamble.
      expect(BoardAudioEngine.canStream(null), isFalse);
      expect(BoardAudioEngine.canStream(''), isFalse);
      expect(BoardAudioEngine.canStream('application/octet-stream'), isFalse);
    });

    test('refuses AAC, which has no decoder at all', () {
      expect(BoardAudioEngine.canStream('audio/mp4'), isFalse);
      expect(BoardAudioEngine.canStream('audio/aac'), isFalse);
    });
  });

  group('AudioPlayerConfig.contentType', () {
    test('defaults to null so an existing board keeps working', () {
      expect(const AudioPlayerConfig().contentType, isNull);
    });

    test('survives a round trip through JSON', () {
      const config = AudioPlayerConfig(fileId: 'f1', contentType: 'audio/mpeg');
      final restored = BoardWidgetConfig.fromJson(config.toJson());

      expect(restored, isA<AudioPlayerConfig>().having((c) => c.contentType, 'contentType', 'audio/mpeg'));
    });

    test('is not runtime state — changing it is a real edit', () {
      // It is captured when the track is picked, alongside the title and length,
      // so it must not be lumped in with the playback anchor.
      const wav = AudioPlayerConfig(fileId: 'f1', contentType: 'audio/wav');
      const mp3 = AudioPlayerConfig(fileId: 'f1', contentType: 'audio/mpeg');

      expect(isWidgetRuntimeOnlyChange(wav, mp3), isFalse);
    });
  });

  group('BoardAssetResolver.openStream', () {
    test('defaults to null, so a resolver that cannot stream needs no code', () {
      expect(_PlainResolver().openStream('f1'), isNull);
    });

    test('the external-display store never streams', () {
      // It is handed whole files over the plugin bus and has no transport of its
      // own to read progressively from.
      expect(CachedBoardAssetStore().openStream('f1'), isNull);
    });
  });
}

/// A resolver that implements only the required half of the contract, standing
/// in for any future one that has no streaming transport.
class _PlainResolver implements BoardAssetResolver {

  @override
  Future<Uint8List> load(String fileId) async => Uint8List(0);

  @override
  Future<Stream<List<int>>>? openStream(String fileId) => null;

}
