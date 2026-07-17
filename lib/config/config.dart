import 'package:h3xboard/config/config_web.dart' if (dart.library.io) 'package:h3xboard/config/config_io.dart';

class Config {

  /// Resolved API URL. On web this prefers the runtime-injected
  /// `window.h3xboardConfig.apiUrl`; on all platforms it falls back to the
  /// compile-time value (--dart-define=API_URL / .env via envied).
  static String get apiUrl => resolvedApiUrl;

  /// Sentry DSN, set at build time via --dart-define=SENTRY_DSN=... . Empty
  /// by default, which makes the Sentry SDK a no-op (local/dev/PR builds).
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

}
