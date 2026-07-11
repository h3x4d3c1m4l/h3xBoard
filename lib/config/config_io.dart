import 'package:h3xboard/config/env.dart';

/// Non-web (Android/iOS/desktop) implementation: there is no injected JS
/// runtime config, so the compile-time value is authoritative:
/// --dart-define=API_URL=... or the .env value via envied (Env.apiUrl).
String get resolvedApiUrl => const String.fromEnvironment('API_URL', defaultValue: Env.apiUrl);
