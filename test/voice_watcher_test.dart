import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/services/audio/voice_watcher.dart';

/// The lifecycle half of [VoiceWatcher] — the half that does not need an audio
/// device.
///
/// Whether it *notices* a voice ending needs a real output to play into, so that
/// is left to the app, as with every other playback path in this repo. What is
/// covered here is the part that silently leaks or misfires: a periodic timer
/// that outlives the widget that started it, or a stopped preview whose callback
/// still arrives and flips the button back under the user.
///
/// These are `testWidgets` rather than plain tests to borrow two things from the
/// test binding: a fake clock that `pump` advances, and a teardown that **fails
/// the test if any timer is still pending**. The second one is the whole
/// assertion in the leak cases — a watcher that forgot to cancel would run
/// forever in the app, and here it simply fails.
void main() {
  const handle = SoundHandle(1);

  testWidgets('a cancelled watch never calls back', (tester) async {
    var ended = false;
    VoiceWatcher()
      ..watch(handle, () => ended = true)
      ..cancel();

    // Advancing an *uncancelled* watch would poll SoLoud, which is exactly what
    // must not happen once the owner has stopped caring.
    await tester.pump(const Duration(seconds: 5));

    expect(ended, isFalse);
  });

  testWidgets('dispose leaves no timer behind', (tester) async {
    VoiceWatcher()
      ..watch(handle, () {})
      ..dispose();
  });

  testWidgets('watching a second voice replaces the first rather than stacking', (tester) async {
    // One dispose has to be enough. If the second watch stacked a timer instead
    // of replacing the first, one would survive and the teardown would say so.
    VoiceWatcher()
      ..watch(handle, () {})
      ..watch(const SoundHandle(2), () {})
      ..dispose();
  });

  testWidgets('cancelling twice, or without a watch, is harmless', (tester) async {
    VoiceWatcher()
      ..cancel()
      ..cancel()
      ..dispose();
  });
}
