import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

/// Centers [child] in the room the page has, and scrolls it once that room runs
/// out — a form that fits looks exactly like a plain [Center], and one that no
/// longer fits scrolls instead of overflowing.
///
/// This is what the login form needs on a tablet: [ScaffoldPage] shrinks its
/// content box by the keyboard height ([ScaffoldPage.resizeToAvoidBottomInset]
/// defaults to `true`), and an iPad keyboard takes ~350px of an 834px landscape
/// screen. A plain [Center] over a [Column] then overflows the moment the form
/// grows — register mode's two extra fields, a server warning, an error bar —
/// and the controls under the keyboard cannot be reached at all.
///
/// The trick it hides: a [SingleChildScrollView] hands its child *unbounded*
/// height, so a [Center] inside one has nothing to center against and collapses
/// onto the content. Giving that child the viewport's own height as a **minimum**
/// puts the centering back — it fills the viewport while the content is short,
/// and grows past it once the content is tall.
///
/// [padding] MUST be handed to this widget rather than wrapped around it, for
/// two reasons: it has to scroll with the content (a gap outside the viewport is
/// dead space the form cannot use), and its vertical half has to come off the
/// minimum height. Skip that subtraction and the content box is always
/// `viewport + padding.vertical` tall, which leaves every page scrollable by
/// exactly the padding it added.
class CenteredScrollArea extends StatelessWidget {

  /// The content to center, and to scroll when it outgrows the viewport.
  final Widget child;

  /// Padding *inside* the scroll view: a gutter to the screen edges, and a little
  /// room past each end so the first and last control come to rest clear of the
  /// edge rather than flush against it.
  final EdgeInsets padding;

  const CenteredScrollArea({super.key, required this.child, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // An unbounded page (nothing in this app does that today) has no height
        // to center against, so the content simply shrink-wraps.
        final minHeight = constraints.hasBoundedHeight
            ? math.max(0.0, constraints.maxHeight - padding.vertical)
            : 0.0;
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }

}
