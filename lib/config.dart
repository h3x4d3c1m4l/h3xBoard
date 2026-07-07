import 'package:h3xboard/config_web.dart' if (dart.library.io) 'package:h3xboard/config_io.dart';

class Config {

  /// Resolved API URL. On web this prefers the runtime-injected
  /// `window.h3xboardConfig.apiUrl`; on all platforms it falls back to the
  /// compile-time value (--dart-define=API_URL / .env via envied).
  static String get apiUrl => resolvedApiUrl;

}
