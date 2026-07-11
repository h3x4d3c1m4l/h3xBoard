import 'dart:js_interop';

import 'package:h3xboard/config/env.dart';

@JS('h3xboardConfig')
external _RuntimeConfig? get _runtimeConfig;

extension type _RuntimeConfig._(JSObject _) implements JSObject {

  external String? get apiUrl;

}

/// Web implementation: runtime value from `window.h3xboardConfig` (injected by
/// the Docker entrypoint from the API_URL env var) wins; otherwise the
/// compile-time value.
String get resolvedApiUrl {
  final runtime = _runtimeConfig?.apiUrl;
  if (runtime != null && runtime.isNotEmpty) return runtime;
  return const String.fromEnvironment('API_URL', defaultValue: Env.apiUrl);
}
