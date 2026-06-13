import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

// Lazily-initialized, self-contained audio engine for the piano widget.
//
// On first use it initializes SoLoud and pre-loads one synthesized waveform
// per semitone (C4..B5, enough for two octaves). Each note gets its own
// AudioSource so several keys can sound at once (polyphony). All audio calls
// are guarded so that a platform/build without working audio simply produces
// no sound while the keyboard stays usable.
class PianoAudio {

  PianoAudio._();

  static final PianoAudio instance = PianoAudio._();

  // MIDI range covering the widget's maximum of two octaves (C4..B5).
  static const int lowestMidi = 60;
  static const int highestMidi = 83;

  final Map<int, AudioSource> _sources = {};
  Future<void>? _initFuture;

  Future<void> _ensureReady() => _initFuture ??= _init();

  Future<void> _init() async {
    final soloud = SoLoud.instance;
    if (!soloud.isInitialized) {
      await soloud.init();
    }

    for (var midi = lowestMidi; midi <= highestMidi; midi++) {
      final source = await soloud.loadWaveform(WaveForm.triangle, true, 1, 0.5);
      soloud.setWaveformFreq(source, _frequencyForMidi(midi));
      _sources[midi] = source;
    }
  }

  // Plays the given MIDI note with a short decay so it sounds like a struck
  // key rather than a sustained tone.
  Future<void> playNote(int midiNote) async {
    try {
      await _ensureReady();

      final source = _sources[midiNote];
      if (source == null) {
        return;
      }

      final soloud = SoLoud.instance;
      final handle = soloud.play(source, volume: 0.6);
      soloud
        ..fadeVolume(handle, 0, const Duration(milliseconds: 700))
        ..scheduleStop(handle, const Duration(milliseconds: 750));
    } on Object catch (error, stackTrace) {
      // On web, audio needs the flutter_soloud <script> tags in web/index.html;
      // without them SoLoud.init() throws. Keep the keyboard usable regardless,
      // but log so the cause is visible during development.
      debugPrint('PianoAudio.playNote failed: $error\n$stackTrace');
    }
  }

  static double _frequencyForMidi(int midiNote) => 440 * pow(2, (midiNote - 69) / 12).toDouble();

}
