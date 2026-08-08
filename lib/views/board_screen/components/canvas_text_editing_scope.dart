import 'package:fluent_ui/fluent_ui.dart';

/// Marks a subtree as somewhere the user types, so the board stops competing for
/// the keyboard.
///
/// `board.dart` installs a `HardwareKeyboard` handler, and those run *before* the
/// focus tree — so the board sees every key first and claims some of them: `L`
/// arms the laser, Escape puts things away, Backspace deletes the widget being
/// arranged, arrows nudge it. It already guards against stealing keys from a
/// text field by looking for an `EditableText` above the focused node.
///
/// That check is not enough for an editor that talks to the platform directly.
/// The code editor implements `DeltaTextInputClient` itself rather than wrapping
/// an `EditableText`, so it holds focus without ever appearing in that search —
/// and typing an `l` would fire the laser pointer instead of the letter.
///
/// Wrapping such an editor in this widget tells the board to keep its hands off.
/// Deliberately a bare marker with no state: the board only needs to find the
/// *type* in the ancestor chain of whatever currently has focus, and keeping it
/// dumb means it never has to know which editor package is in use.
class CanvasTextEditingScope extends StatelessWidget {

  final Widget child;

  const CanvasTextEditingScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;

}
