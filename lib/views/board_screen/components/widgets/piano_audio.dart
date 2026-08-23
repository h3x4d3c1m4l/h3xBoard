import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:h3xboard/services/audio/board_audio_engine.dart';

// Synthesized tones for the piano widget.
//
// Starting the engine belongs to [BoardAudioEngine] — the piano is one of
// several things on a board that make noise, and they must not race on
// initialization. What stays here is piano-specific: one pre-built waveform per
// semitone (C4..B5, two octaves), so several keys can sound at once.
//
// Audio being unavailable is not an error case to handle: the keyboard stays
// playable and simply makes no sound.
class PianoAudio {

  PianoAudio._();

  static final PianoAudio instance = PianoAudio._();

  // MIDI range covering the widget's maximum of two octaves (C4..B5).
  static const int lowestMidi = 60;
  static const int highestMidi = 83;

  final Map<int, AudioSource> _sources = {};
  Future<void>? _tonesFuture;

  Future<void> _ensureTones() => _tonesFuture ??= _buildTones();

  Future<void> _buildTones() async {
    if (!await BoardAudioEngine.instance.ensureInitialized()) {
      // Leave the field clear so a later key press retries — on web the audio
      // context stays blocked until the page has seen a user gesture.
      _tonesFuture = null;
      return;
    }

    final soloud = SoLoud.instance;
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
      await _ensureTones();

      final source = _sources[midiNote];
      if (source == null) return;

      final handle = await BoardAudioEngine.instance.play(source, volume: 0.6);
      if (handle == null) return;

      SoLoud.instance
        ..fadeVolume(handle, 0, const Duration(milliseconds: 700))
        ..scheduleStop(handle, const Duration(milliseconds: 750));
    } on Object catch (error, stackTrace) {
      debugPrint('PianoAudio.playNote failed: $error\n$stackTrace');
    }
  }

  static double _frequencyForMidi(int midiNote) => 440 * pow(2, (midiNote - 69) / 12).toDouble();

}
