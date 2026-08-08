import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

/// Gives the editor the hardware-keyboard behaviour re_editor leaves out on
/// Android and iOS.
///
/// `CodeEditor.build` branches on the platform: on desktop it wraps itself in
/// `_CodeShortcuts` + `_CodeShortcutActions`, and on Android and iOS it wraps
/// itself in a bare `Focus` that handles Backspace and Enter and nothing else.
/// The assumption is a soft keyboard with no arrows and no Tab — which stops
/// being true on an iPad with a Magic Keyboard, an Android tablet with a
/// keyboard case, or the iOS simulator, where the Mac's keyboard is the
/// keyboard. There the keys fall through to Flutter's defaults, which read an
/// arrow as `DirectionalFocusIntent` and Tab as `NextFocusIntent`: press Down in
/// a program and focus leaves the editor.
///
/// Both halves have to be supplied. Mapping the keys to re_editor's own intents
/// would not help, because on those platforms it registers no actions to handle
/// them either — so these drive [CodeLineEditingController] directly, which is
/// public API and exactly what re_editor's own actions call.
///
/// Installed only where re_editor does not, so on desktop its own shortcuts
/// stay closest to the focus and keep winning.
class EditorHardwareKeys extends StatelessWidget {

  final CodeLineEditingController controller;

  /// A read-only pane still moves its caret and scrolls; it just cannot edit.
  final bool readOnly;

  final Widget child;

  const EditorHardwareKeys({
    super.key,
    required this.controller,
    required this.readOnly,
    required this.child,
  });

  /// Matches re_editor's own platform test (`kIsAndroid || kIsIOS` in its
  /// `_consts.dart`), so this covers exactly the gap it leaves and never
  /// competes with the shortcuts it does install.
  static bool get _reEditorInstallsNoShortcuts =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!_reEditorInstallsNoShortcuts) return child;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveCaret(AxisDirection.up),
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveCaret(AxisDirection.down),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveCaret(AxisDirection.left),
        SingleActivator(LogicalKeyboardKey.arrowRight): _MoveCaret(AxisDirection.right),
        SingleActivator(LogicalKeyboardKey.home): _MoveToLineEdge(false),
        SingleActivator(LogicalKeyboardKey.end): _MoveToLineEdge(true),
        SingleActivator(LogicalKeyboardKey.tab): _Indent(false),
        SingleActivator(LogicalKeyboardKey.tab, shift: true): _Indent(true),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _MoveCaret: CallbackAction<_MoveCaret>(
            onInvoke: (intent) {
              controller.moveCursor(intent.direction);
              return null;
            },
          ),
          _MoveToLineEdge: CallbackAction<_MoveToLineEdge>(
            onInvoke: (intent) {
              if (intent.toEnd) {
                controller.moveCursorToLineEnd();
              } else {
                controller.moveCursorToLineStart();
              }
              return null;
            },
          ),
          _Indent: CallbackAction<_Indent>(
            onInvoke: (intent) {
              // Swallowed rather than passed on even when read-only: letting Tab
              // through would traverse focus, which is the bug this exists to
              // fix, and a mirror has nowhere sensible to send it anyway.
              if (readOnly) return null;
              if (intent.outdent) {
                controller.applyOutdent();
              } else {
                controller.applyIndent();
              }
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }

}

class _MoveCaret extends Intent {

  final AxisDirection direction;

  const _MoveCaret(this.direction);

}

class _MoveToLineEdge extends Intent {

  final bool toEnd;

  const _MoveToLineEdge(this.toEnd);

}

class _Indent extends Intent {

  final bool outdent;

  const _Indent(this.outdent);

}
