import 'package:fluent_ui/fluent_ui.dart';

/// A side slot of the top bar, sized to whichever side is wider: [child] is
/// rendered on top of an invisible [counterweight] (the *other* side's content),
/// so both slots end up equally wide and the Expanded centre between them is
/// truly centred in the bar.
class BalancedSide extends StatelessWidget {

  final AlignmentGeometry alignment;
  final Widget counterweight;
  final Widget child;

  const BalancedSide({
    super.key,
    required this.alignment,
    required this.counterweight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: alignment,
      children: [
        // The counterweight is a spacer only — it must not paint, react to
        // pointers, take focus, or show up in semantics.
        ExcludeFocus(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: Opacity(opacity: 0, child: counterweight),
            ),
          ),
        ),
        child,
      ],
    );
  }

}
