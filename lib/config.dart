import 'dart:js_interop';

import 'package:h3xboard/env.dart';

@JS('h3xboardConfig')
external _RuntimeConfig? get _runtimeConfig;

extension type _RuntimeConfig._(JSObject _) implements JSObject {

  external String? get apiUrl;

}

class Config {

  /// Runtime value from `window.h3xboardConfig` (injected by the Docker
  /// entrypoint from the API_URL env var) wins; otherwise the compile-time
  /// value: --dart-define=API_URL=... or .env via envied (Env.apiUrl).
  static String get apiUrl {

    final runtime = _runtimeConfig?.apiUrl;
    if (runtime != null && runtime.isNotEmpty) return runtime;
    return const String.fromEnvironment('API_URL', defaultValue: Env.apiUrl);
  }

}
