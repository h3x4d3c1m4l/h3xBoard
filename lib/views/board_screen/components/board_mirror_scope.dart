import 'package:fluent_ui/fluent_ui.dart';

/// Marks a board subtree as a *mirror* — a render of someone else's board, as
/// shown on the attached external display or to a web viewer.
///
/// Most widgets need no say in this: they draw their config and have nothing to
/// operate. The ones that do — a code editor, a Run button — have no other way
/// to tell, because [ReadOnlyBoard] hands every widget the same
/// `buildWidget(config, (_) {})` the widget catalog uses, and a callback that
/// quietly discards its argument is indistinguishable from one that works. A
/// pane left editable on a mirror accepts typing and then snaps back the moment
/// the presenter's next update lands, which reads as a bug.
///
/// The editor deliberately does not wrap its own board, so [isMirror] is false
/// there by omission — the same shape as [BoardAssets], and for the same reason:
/// the normal case should need no ceremony.
class BoardMirrorScope extends InheritedWidget {

  const BoardMirrorScope({super.key, required super.child});

  /// Whether this subtree is a mirror rather than the board being edited.
  static bool isMirror(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BoardMirrorScope>() != null;

  @override
  bool updateShouldNotify(BoardMirrorScope oldWidget) => false;

}
