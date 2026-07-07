import 'dart:async';

/// Non-web stub: fullscreen is a browser concept, so on Android/iOS/desktop the
/// service is inert. Kept API-compatible with the web implementation so callers
/// need no platform checks.
class FullscreenServiceImpl {

  bool get isSupported => false;

  bool get isFullscreen => false;

  Stream<bool> get onChange => const Stream<bool>.empty();

  Future<void> requestFullscreen() async {}

  Future<void> exitFullscreen() async {}

  void dispose() {}

}
