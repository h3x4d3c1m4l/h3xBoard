import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// The one place that starts SoLoud and holds decoded audio for the board.
///
/// Everything that makes noise — the piano, sound pads, the audio player — goes
/// through here rather than calling `SoLoud.instance.init()` itself. So several
/// widgets waking up at once can't race on initialization.
///
/// Nothing here throws. Audio is unavailable in more situations than it is
/// worth branching on. Take a web build without the flutter_soloud `<script>`
/// tags, a browser that hasn't had a user gesture yet, or a machine with no
/// output device. In every one of them the right behaviour is the same. The
/// widget stays usable and simply makes no sound. Callers get `false`/`null` and
/// carry on.
class BoardAudioEngine {

  BoardAudioEngine._();

  static final BoardAudioEngine instance = BoardAudioEngine._();

  Future<bool>? _initFuture;
  final Map<String, Future<AudioSource?>> _sources = {};

  /// Whether the engine has been started successfully. A pure query — it never
  /// kicks off initialization, so a `build()` can ask without side effects.
  bool get isReady => SoLoud.instance.isInitialized;

  /// Starts the engine if it isn't running, returning whether audio is usable.
  ///
  /// A failed attempt is deliberately **not** cached. On web the audio context
  /// stays blocked until the page has seen a user gesture. The first attempt can
  /// therefore fail and the next one — after a tap — succeed. Caching the
  /// failure would make that first tap poison every later one.
  Future<bool> ensureInitialized() => _initFuture ??= _init();

  Future<bool> _init() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) {
        await _configureAudioSession();
        await soloud.init();
      }
      return true;
    } on Object catch (error, stackTrace) {
      debugPrint('BoardAudioEngine.init failed: $error\n$stackTrace');
      _initFuture = null;
      return false;
    }
  }

  /// Claims the platform's audio session before the engine opens a device.
  ///
  /// flutter_soloud deliberately leaves this to the app: its miniaudio backend
  /// initializes CoreAudio with `sessionCategory = none` and
  /// `noAudioSessionActivate = true`, and says so — "the app is responsible for
  /// calling `[AVAudioSession setActive:YES]`". Skip it and iOS keeps its
  /// default `SoloAmbient` category, which the ring/silent switch mutes. Voices
  /// play, handles stay valid, the UI shows a sound running — and nothing comes
  /// out of the iPad. `playback` is the category that says this app's audio is
  /// the point, so silent mode no longer applies to it.
  ///
  /// Called **before** `SoLoud.init()`: the audio unit should start under the
  /// category it is going to run with, rather than having one swapped in under
  /// it. Failure is not fatal — audio_session ships no Windows or Linux
  /// implementation, so `instance` throws there, and the engine must still come
  /// up on the platforms whose default session was already fine.
  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            usage: AndroidAudioUsage.media,
            contentType: AndroidAudioContentType.music,
          ),
          // Ducking rather than pausing: a board sound is short and incidental,
          // so music playing alongside it should dip, not stop.
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );
      await session.setActive(true);
    } on Object catch (error, stackTrace) {
      debugPrint('BoardAudioEngine.configureAudioSession failed: $error\n$stackTrace');
    }
  }

  /// The decoded source for [key], loading it through [readBytes] the first time.
  ///
  /// Keyed by the caller (a file id, a note number), so two pads pointing at the
  /// same sound decode it once and share it. [readBytes] is only awaited on a
  /// miss, which keeps the caller from fetching bytes it turns out not to need.
  Future<AudioSource?> source(String key, Future<Uint8List> Function() readBytes) {
    return _sources.putIfAbsent(key, () => _load(key, readBytes));
  }

  Future<AudioSource?> _load(String key, Future<Uint8List> Function() readBytes) async {
    try {
      if (!await ensureInitialized()) {
        unawaited(_sources.remove(key));
        return null;
      }
      // loadMem over loadFile: the bytes arrive from the file service (or, on a
      // mirror, over the wire) and never touch disk. And on web, loadMem is the
      // only load that works. LoadMode.memory keeps the compressed file resident
      // so seeking an MP3 doesn't stall — see the note in SoLoud.seek.
      return await SoLoud.instance.loadMem(key, await readBytes(), mode: LoadMode.memory);
    } on Object catch (error, stackTrace) {
      debugPrint('BoardAudioEngine.source($key) failed: $error\n$stackTrace');
      // Forget the failure so a later attempt can retry — the bytes may simply
      // not have been reachable yet.
      unawaited(_sources.remove(key));
      return null;
    }
  }

  /// The containers SoLoud can sniff from a chunk of a stream, and therefore the
  /// only ones that can be played before they have fully arrived.
  ///
  /// Narrower than what it can decode from a complete file. `BufferType.auto`
  /// detects MP3 and Ogg (Vorbis or Opus). WAV and FLAC have to be handed over
  /// whole, through [source], which handles them fine.
  static bool canStream(String? contentType) => switch (contentType) {
        'audio/mpeg' || 'audio/ogg' => true,
        _ => false,
      };

  /// A source fed progressively from [chunks], so playback can start once a
  /// couple of seconds have arrived rather than after the whole file.
  ///
  /// Returns null when audio is unavailable or the stream could not be opened.
  /// Callers treat that as "fall back to [source]", not as an error. There is
  /// always a whole-file path that works.
  ///
  /// [onBuffering] fires when playback stalls waiting for data and again when it
  /// resumes. So the transport can show that it is waiting on the network rather
  /// than appearing to have frozen.
  ///
  /// Unlike [source] this is **not memoized**. A buffer stream is fed exactly
  /// once. Handing a second caller a source whose stream has already ended would
  /// give them a track they cannot restart.
  ///
  /// Not being memoized also means nothing else can free it: the caller owns
  /// what it gets back and hands it to [disposeStreamingSource] when it stops
  /// playing. A `preserved` stream holds the whole decoded track, so one that is
  /// never handed back stays resident for the life of the process.
  Future<AudioSource?> streamingSource(
    String key,
    Stream<List<int>> chunks, {
    void Function(bool isBuffering)? onBuffering,
  }) async {
    try {
      if (!await ensureInitialized()) return null;

      final source = SoLoud.instance.setBufferStream(
        // The container is sniffed from the first chunk, which is why the
        // caller has to have checked [canStream] first.
        format: BufferType.auto,
        // Preserved rather than released: released frees each buffer as it is
        // played, which makes the stream unseekable and single-instance. And a
        // player with a scrub bar is exactly a thing that seeks.
        bufferingType: BufferingType.preserved,
        bufferingTimeNeeds: _bufferingSeconds,
        // The handle and elapsed time SoLoud also reports are of no use here:
        // there is one stream per player, and the transport already knows its own
        // position.
        onBuffering: onBuffering == null ? null : (isBuffering, _, _) => onBuffering(isBuffering),
      );

      // Deliberately not awaited: the point is to return a playable source now
      // and keep filling it behind the caller's back.
      unawaited(_pump(source, chunks));
      return source;
    } on Object catch (error, stackTrace) {
      debugPrint('BoardAudioEngine.streamingSource($key) failed: $error\n$stackTrace');
      return null;
    }
  }

  /// How much audio has to be buffered before a stalled stream resumes. Two
  /// seconds is SoLoud's own default and a reasonable trade: long enough to ride
  /// out a hiccup, short enough that starting doesn't feel deliberate.
  static const double _bufferingSeconds = 2;

  Future<void> _pump(AudioSource source, Stream<List<int>> chunks) async {
    try {
      await for (final chunk in chunks) {
        SoLoud.instance.addAudioDataStream(source, Uint8List.fromList(chunk));
      }
      // Tells the engine the track has a real end, so it stops rather than
      // waiting forever for data that is never coming.
      SoLoud.instance.setDataIsEnded(source);
    } on Object catch (error, stackTrace) {
      debugPrint('BoardAudioEngine stream pump failed: $error\n$stackTrace');
      // End it anyway: a truncated track that stops is better than one that
      // hangs waiting on a connection that already died.
      try {
        SoLoud.instance.setDataIsEnded(source);
      } on Object {
        // The source may already be disposed; nothing left to end.
      }
    }
  }

  /// The length of an already-loaded source, or null when it isn't loaded or the
  /// engine never started. Used to label a sound without decoding it twice.
  Duration? lengthOf(AudioSource source) {
    try {
      return isReady ? SoLoud.instance.getLength(source) : null;
    } on Object {
      return null;
    }
  }

  /// Plays [source] once, returning its handle so the caller can stop it later.
  /// Null when audio is unavailable or the voice could not be created.
  ///
  /// Past its 16-voice ceiling SoLoud declines without throwing, and hands back
  /// a zeroed handle rather than refusing outright. That handle is checked here
  /// so it never reaches a caller. A zeroed handle that travelled would leave a
  /// pad showing a stop badge for a voice that never sounded. And the reaper
  /// polling it would see a handle that was invalid from the start.
  Future<SoundHandle?> play(AudioSource source, {double volume = 1.0}) async {
    try {
      if (!await ensureInitialized()) return null;
      final handle = SoLoud.instance.play(source, volume: volume);
      return SoLoud.instance.getIsValidVoiceHandle(handle) ? handle : null;
    } on Object catch (error, stackTrace) {
      debugPrint('BoardAudioEngine.play failed: $error\n$stackTrace');
      return null;
    }
  }

  /// Stops every handle in [handles], ignoring the ones that already finished.
  Future<void> stopAll(Iterable<SoundHandle> handles) async {
    for (final handle in handles) {
      try {
        await SoLoud.instance.stop(handle);
      } on Object {
        // A voice that ended on its own is already gone; nothing to report.
      }
    }
  }

  /// Frees a source that came from [streamingSource].
  ///
  /// Separate from [release] because streaming sources are never in the cache:
  /// they belong to one player rather than being shared by key. So the player
  /// that asked for one is the only thing that can free it.
  Future<void> disposeStreamingSource(AudioSource source) async {
    try {
      await SoLoud.instance.disposeSource(source);
    } on Object {
      // Already disposed, or the engine went away underneath it. Either way
      // there is nothing left to free.
    }
  }

  /// Drops the cached source for [key]. Called when a widget stops pointing at a
  /// file, so a board that cycled through many sounds doesn't hold all of them.
  Future<void> release(String key) async {
    final pending = _sources.remove(key);
    if (pending == null) return;
    try {
      final source = await pending;
      if (source != null) await SoLoud.instance.disposeSource(source);
    } on Object {
      // Disposing a source that never loaded is not worth reporting.
    }
  }

}
