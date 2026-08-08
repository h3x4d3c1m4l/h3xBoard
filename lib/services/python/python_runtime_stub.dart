import 'package:h3xboard/services/python/python_runtime.dart';

PythonRuntime createPythonRuntime() => const UnsupportedPythonRuntime();

/// Stands in where no host for `python.wasm` exists yet — currently iOS and
/// Android, until the Rust runtime lands.
///
/// Deliberately not a thrown error: the widget stays fully useful on those
/// platforms. Code and the last output are held in the board config, so they
/// still display and still mirror to the second screen; only running is
/// unavailable, and the widget says so plainly rather than failing oddly.
class UnsupportedPythonRuntime implements PythonRuntime {

  const UnsupportedPythonRuntime();

  @override
  bool get isSupported => false;

  @override
  Future<void> ready() async {}

  @override
  Future<PythonResult> run(String code, {String stdin = ''}) async =>
      const PythonResult.failure('Running Python is not available on this platform yet.');

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}

}
