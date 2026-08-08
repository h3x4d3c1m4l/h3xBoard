import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:h3xboard/services/python/python_runtime.dart';
import 'package:h3xboard/services/rust/api/python.dart' as rust;
import 'package:h3xboard/services/rust/frb_generated.dart';

/// Runs Python through the Rust interpreter, on iOS and Android.
///
/// The same `python.wasm` the web build hands to the browser's engine, executed
/// by wasmi instead — see rust/src/python/. Everything that differs between the
/// two hosts is meant to be invisible from here: same argv, same environment,
/// same virtual filesystem, same output cap, so a program produces the same
/// bytes on a phone as in a classroom's browser.
///
/// The only visible difference is where the interpreter comes from. On the web
/// the worker fetches it over HTTP; here it is a Flutter asset that has to be
/// pushed across the bridge once, which is what [ready] is for.
class NativePythonRuntime implements PythonRuntime {

  /// Loading is shared by every playground on the board: the bytes are ~20 MB
  /// and the translated interpreter is reused, so the second widget to press Run
  /// must wait for the first one's load rather than start its own.
  static Future<void>? _loading;

  @override
  bool get isSupported => rust.pythonIsSupported();

  @override
  Future<void> ready() => _loading ??= _load();

  static Future<void> _load() async {
    // Lazily, and only here. Calling this from main() would make every platform
    // pay to initialise a bridge that only two of them use, and would make the
    // web build look for a Rust wasm bundle that is deliberately not shipped.
    await RustLib.init();

    // `rootBundle.load` is not cached — despite the bundle being a
    // CachingAssetBundle, only loadString and loadStructuredData are — so each
    // call materialises another copy of these on the Dart heap. Loading once,
    // here, and letting Rust keep them is the whole point of this method.
    final wasm = await rootBundle.load('assets/python/python.wasm');
    final stdlib = await rootBundle.load('assets/python/python314.zip');

    await rust.pythonLoad(wasm: _view(wasm), stdlib: _view(stdlib));
  }

  /// A view rather than a copy: these are 7.6 MB and 12.5 MB, and duplicating
  /// them on the way to the bridge is 20 MB of avoidable peak memory.
  static Uint8List _view(ByteData data) => Uint8List.sublistView(data);

  @override
  Future<PythonResult> run(String code, {String stdin = ''}) async {
    try {
      await ready();
      final outcome = await rust.pythonRun(code: code, stdin: stdin);
      return PythonResult(
        stdout: outcome.stdout,
        stderr: outcome.stderr,
        exitCode: outcome.exitCode,
        truncated: outcome.truncated,
        duration: Duration(milliseconds: outcome.durationMs.toInt()),
      );
    } catch (error) {
      // A program's own mistakes never land here — those come back as a
      // traceback in stderr. This is the interpreter failing to start at all,
      // which is worth showing rather than swallowing.
      _loading = null;
      return PythonResult.failure('Could not start Python: $error');
    }
  }

  @override
  Future<void> cancel() async {
    // Synchronous on the Rust side and lock-free, so it lands while `run` is
    // still in flight rather than queueing behind it.
    if (_loading != null) rust.pythonCancel();
  }

  @override
  void dispose() {
    // Nothing to release: the interpreter is deliberately shared and outlives
    // any one widget, so a playground being deleted must not take it away from
    // the others.
  }

}
