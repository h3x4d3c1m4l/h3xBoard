import 'package:flutter/widgets.dart';

/// Drops focus — and with it the software keyboard — when the user taps outside
/// the focused text field.
///
/// Flutter already does this everywhere but one case. [EditableText] wraps itself
/// in a [TextFieldTapRegion] and invokes [EditableTextTapOutsideIntent] on a tap
/// outside; the default action unfocuses for every platform and pointer kind
/// *except* PointerDeviceKind.touch on Android/iOS/Fuchsia when not on web. This
/// app ships to Android, iOS and web, so that carve-out is exactly — and only —
/// the gap we have to close: a finger tap on a phone or tablet.
///
/// Replacing the action rather than extending it also drops one wart: the default
/// *throws* for PointerDeviceKind.trackpad on those platforms. Unreachable today,
/// but there is no reason to reproduce it.
///
/// Flutter registers that action through [Action.overridable], so replacing it
/// from an ancestor [Actions] is the sanctioned fix. Sitting above the router, one
/// install covers every screen, dialog and flyout at once — dialogs are pushed
/// into the same navigator's overlay, and actions resolve by element ancestry.
///
/// Going through the intent rather than a root [GestureDetector] is deliberate:
/// the board parks a scale and a long-press recognizer over the whole canvas, and
/// flutter_drawing_board adds a placeholder pan recognizer, so a root tap
/// recognizer would lose the arena there and fire unreliably. A tap region instead
/// reacts to pointer events straight from the hit-test path and never enters the
/// arena — it can neither be starved by those recognizers nor disturb them. It
/// also already knows what counts as "inside": the field's prefix and suffix, the
/// selection handles and the copy/paste toolbar all share its group.
///
/// Fields that pass their own `onTapOutside` short-circuit this by design. The
/// on-board label editor relies on that to keep its caret while the style bar is
/// tapped.
class KeyboardDismisser extends StatelessWidget {

  final Widget child;

  const KeyboardDismisser({super.key, required this.child});

  /// One shared instance: [Actions] compares its map by identity, so building a
  /// fresh action per build would notify every dependent for nothing.
  static final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
      onInvoke: (intent) {
        intent.focusNode.unfocus();
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) => Actions(actions: _actions, child: child);

}
