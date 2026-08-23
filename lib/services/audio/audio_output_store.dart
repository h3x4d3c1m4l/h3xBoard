import 'package:h3xboard/services/audio/audio_output_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which speakers a device sends board audio to, backed by
/// shared_preferences.
///
/// Per **device**, not per board. The choice describes the room you are standing
/// in. So a board authored in a classroom does not try to throw sound at a TV
/// when that board is opened again at home.
class AudioOutputStore {

  static const String _outputKey = 'h3xboard.audioOutput';

  final SharedPreferencesAsync _prefs;

  AudioOutputStore([SharedPreferencesAsync? prefs]) : _prefs = prefs ?? SharedPreferencesAsync();

  /// The stored output, or `null` when the user has never chosen one. An
  /// unreadable value reads as `null` too: a preference written by a build that
  /// named its outputs differently is not worth failing a launch over.
  Future<AudioOutput?> getOutput() async {
    final value = await _prefs.getString(_outputKey);
    return AudioOutput.values.where((output) => output.name == value).firstOrNull;
  }

  Future<void> setOutput(AudioOutput output) => _prefs.setString(_outputKey, output.name);

}
