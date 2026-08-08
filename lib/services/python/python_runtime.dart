// Three ways to run Python and only two things a conditional import can see, so
// the last step of the choice happens at runtime — see python_runtime_io.dart.
// Clauses are tried in order and the first satisfied one wins, which is why
// js_interop comes first: on the web both it and dart.library.io would match.
import 'package:h3xboard/services/python/python_runtime_stub.dart'
    if (dart.library.js_interop) 'package:h3xboard/services/python/python_runtime_web.dart'
    if (dart.library.io) 'package:h3xboard/services/python/python_runtime_io.dart' as impl;

/// What one run of a program produced.
class PythonResult {

  final String stdout;
  final String stderr;

  /// 0 when the program finished normally. Anything else means it raised, and
  /// [stderr] holds the traceback.
  final int exitCode;

  /// Output hit the per-run cap and was cut short. Worth telling the user about:
  /// a program that prints in a loop is usually a mistake, and silently dropping
  /// the tail would make it look like the program stopped early instead.
  final bool truncated;

  final Duration duration;

  const PythonResult({
    required this.stdout,
    required this.stderr,
    this.exitCode = 0,
    this.truncated = false,
    this.duration = Duration.zero,
  });

  const PythonResult.failure(String message)
      : stdout = '',
        stderr = message,
        exitCode = 1,
        truncated = false,
        duration = Duration.zero;

  bool get succeeded => exitCode == 0;

}

/// Runs Python, wherever this build happens to be running.
///
/// The one artifact — CPython built for wasm32-wasi — is the same on every
/// platform; only the host that executes it differs. Keeping that behind an
/// interface is what lets the widget stay ignorant of which host it got, and
/// what lets a second host be added without the widget changing.
abstract class PythonRuntime {

  /// False where no host is available yet. The widget stays usable — code and
  /// the last output still show and still mirror — but cannot run anything.
  bool get isSupported;

  /// Loads the interpreter. Safe to call repeatedly; only the first does work.
  Future<void> ready();

  /// Runs [code] to completion, feeding [stdin] to `input()`.
  ///
  /// Never throws for a *program* error — a traceback comes back in
  /// [PythonResult.stderr] with a non-zero exit code, because a pupil's mistake
  /// is a normal outcome here, not an exception.
  Future<PythonResult> run(String code, {String stdin});

  /// Stops a running program. The only thing that reliably ends `while True:`,
  /// so it must not depend on the program cooperating.
  Future<void> cancel();

  void dispose();

}

/// The runtime for this platform.
PythonRuntime createPythonRuntime() => impl.createPythonRuntime();
