import 'dart:io' show Platform;

import 'package:h3xboard/services/python/native_python_runtime.dart';
import 'package:h3xboard/services/python/python_runtime.dart';
import 'package:h3xboard/services/python/python_runtime_stub.dart' show UnsupportedPythonRuntime;

/// Picks between the Rust interpreter and the stub, for everything that is not
/// the web.
///
/// This file exists because a conditional import cannot make this choice:
/// `dart.library.io` is true on a phone, on every desktop, and in the `flutter
/// test` VM alike, and only two of those three have an interpreter compiled in
/// (see the target-gated dependency in rust/Cargo.toml). So the import narrows
/// it to "not web" and the last step happens at runtime.
///
/// [Platform] rather than `defaultTargetPlatform`, deliberately: the latter
/// reports Android on every host under `flutter test`, which would hand the
/// widget tests a runtime that wants 20 MB of assets and a dylib CI never built.
PythonRuntime createPythonRuntime() =>
    Platform.isAndroid || Platform.isIOS ? NativePythonRuntime() : const UnsupportedPythonRuntime();
