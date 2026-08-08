/// The languages the Code Playground can run.
///
/// Only Python today. The enum exists rather than being assumed away because the
/// widget is built to gain more: the runtime hides behind an interface, and the
/// toolbar already reads its label from here, so adding one is a new case rather
/// than a new design.
library;

/// The CPython this app ships, built for wasm32-wasi.
///
/// Must match `assets/python/python.wasm`. Both this and the stdlib zip's name
/// are produced by `tool/build_python_wasm.sh`, so bump all three together when
/// upgrading — see docs/python-wasm-build.md.
const String kPythonVersion = '3.14.7';

enum ProgrammingLanguage {

  python('Python', kPythonVersion, 'py');

  const ProgrammingLanguage(this.displayName, this.version, this.fileExtension);

  /// Shown on its own in menus, and with [version] on the widget's toolbar —
  /// which version is running is not a detail when the point is teaching.
  final String displayName;

  final String version;

  final String fileExtension;

  /// What the toolbar reads: "Python 3.14.7".
  String get label => '$displayName $version';

}
