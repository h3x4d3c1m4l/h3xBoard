import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Drops focus — and with it the software keyboard — when the user taps outside
/// the focused text field, and **only** when it really was a tap.
///
/// Flutter already does this everywhere but one case. [EditableText] wraps itself
/// in a [TextFieldTapRegion] and invokes [EditableTextTapOutsideIntent] on a tap
/// outside; the default action unfocuses for every platform and pointer kind
/// *except* PointerDeviceKind.touch on Android/iOS/Fuchsia when not on web. This
/// app ships to Android, iOS and web, so that carve-out is exactly — and only —
/// the gap we have to close: a finger tap on a phone or tablet.
///
/// The catch is that "tap outside" fires on the pointer *down*, and a scroll
/// starts with a pointer down too. Unfocusing there closes the keyboard the
/// instant a finger lands anywhere but the field — so on a page the keyboard has
/// shrunk into scrolling, dragging from outside the field yanked the keyboard
/// away instead of scrolling under it. Flutter pairs the intent with
/// [EditableTextTapUpOutsideIntent] for this: hold on to where the pointer went
/// down, and decide on the way up, once the distance says whether it was a tap
/// or the beginning of a drag. That is the framework's own recipe for it.
///
/// The threshold is [computeHitSlop] rather than a flat [kTouchSlop], so a mouse
/// — which is expected to be steady — is judged by the tighter precise-pointer
/// slop, and every pointer kind still travels one code path.
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
/// Fields that pass their own `onTapOutside` short-circuit this by design: their
/// pointer-down never reaches this widget, so the matching pointer-up finds no
/// recorded start and does nothing. The on-board label editor relies on that to
/// keep its caret while the style bar is tapped.
class KeyboardDismisser extends StatefulWidget {

  final Widget child;

  const KeyboardDismisser({super.key, required this.child});

  @override
  State<KeyboardDismisser> createState() => _KeyboardDismisserState();

}

class _KeyboardDismisserState extends State<KeyboardDismisser> {

  /// Where the last pointer went down outside a focused field, kept until that
  /// same pointer comes back up.
  ///
  /// One pointer rather than a map of them, deliberately: a second finger landing
  /// mid-gesture replaces it, and the first finger's release then matches nothing
  /// and leaves the keyboard alone. Keeping every pointer would mean tracking
  /// which ones never produce an up outside — a drag that ends *on* the field
  /// does not — and a map that only ever grows.
  PointerDownEvent? _lastDownOutside;

  /// Built once: [Actions] compares its map by identity, so a fresh map per build
  /// would notify every dependent for nothing.
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(onInvoke: _onPointerDownOutside),
    EditableTextTapUpOutsideIntent: CallbackAction<EditableTextTapUpOutsideIntent>(onInvoke: _onPointerUpOutside),
  };

  Object? _onPointerDownOutside(EditableTextTapOutsideIntent intent) {
    _lastDownOutside = intent.pointerDownEvent;
    return null;
  }

  Object? _onPointerUpOutside(EditableTextTapUpOutsideIntent intent) {
    final down = _lastDownOutside;
    final up = intent.pointerUpEvent;
    if (down == null || down.pointer != up.pointer) return null;
    _lastDownOutside = null;

    final slop = computeHitSlop(up.kind, MediaQuery.maybeGestureSettingsOf(context));
    if ((up.position - down.position).distance < slop) {
      intent.focusNode.unfocus();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Actions(actions: _actions, child: widget.child);

}
