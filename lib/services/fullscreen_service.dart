import 'dart:async';

import 'package:h3xboard/services/fullscreen_service_web.dart'
    if (dart.library.io) 'package:h3xboard/services/fullscreen_service_io.dart';

/// Toggles browser fullscreen on web; a no-op on other platforms. The platform
/// split lives in fullscreen_service_web.dart / fullscreen_service_io.dart,
/// selected by conditional import so mobile builds never reference dart:js_interop.
class FullscreenService {

  final FullscreenServiceImpl _impl = FullscreenServiceImpl();

  bool get isSupported => _impl.isSupported;

  bool get isFullscreen => _impl.isFullscreen;

  Stream<bool> get onChange => _impl.onChange;

  Future<void> requestFullscreen() => _impl.requestFullscreen();

  Future<void> exitFullscreen() => _impl.exitFullscreen();

  void dispose() => _impl.dispose();

}
