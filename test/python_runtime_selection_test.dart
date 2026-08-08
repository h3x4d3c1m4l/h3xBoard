import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/services/python/python_runtime.dart';
import 'package:h3xboard/services/python/python_runtime_io.dart' as io;
import 'package:h3xboard/services/python/python_runtime_stub.dart' show UnsupportedPythonRuntime;

/// Which host `createPythonRuntime()` hands back.
///
/// Three implementations behind one conditional import, and the last step of the
/// choice happens at runtime — so nothing else in the build would notice if it
/// went wrong. A mistake here is silent in exactly the worst way: a class gets
/// "running Python is not available on this platform" and the app is otherwise
/// perfectly healthy.
void main() {
  group('choosing a Python host', () {
    test('a desktop or a test VM gets the stub, not the Rust interpreter', () {
      // The interpreter is only compiled for iOS and Android (see the
      // target-gated dependency in rust/Cargo.toml), so everything else must
      // land on the stub. This is also what stops `flutter test` trying to load
      // 20 MB of assets and a dylib that CI never built.
      expect(Platform.isAndroid || Platform.isIOS, isFalse,
          reason: 'precondition: these tests run on a desktop host');

      expect(io.createPythonRuntime(), isA<UnsupportedPythonRuntime>());
      expect(createPythonRuntime(), isA<UnsupportedPythonRuntime>());
      expect(createPythonRuntime().isSupported, isFalse);
    });

    test('the stub still leaves the widget usable', () async {
      // Losing the Run button is fine; losing the code is not. Everything the
      // playground displays lives in its config, so a platform without an
      // interpreter still shows and mirrors the last result.
      final runtime = createPythonRuntime();
      await runtime.ready();

      final result = await runtime.run('print("hi")');
      expect(result.succeeded, isFalse);
      expect(result.stderr, isNotEmpty, reason: 'it must say why, not fail silently');

      await runtime.cancel();
      runtime.dispose();
    });
  });
}
