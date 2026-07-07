import 'package:fluent_ui/fluent_ui.dart';

/// Overlays soft top/bottom fade shadows on a scrollable [child], each appearing
/// only when there is content scrolled off that edge — the standard affordance
/// that "there's more above/below". The shadows sit on top of the child (they
/// don't take layout space), so the scroll view still runs edge to edge.
///
/// Wrap the scroll view directly:
///
/// ```dart
/// ScrollShadow(
///   child: SingleChildScrollView(...),
/// )
/// ```
class ScrollShadow extends StatefulWidget {
  /// The scrollable widget to shadow. Its primary [ScrollController] (or the one
  /// on its [Scrollable]) drives the shadow visibility.
  final Widget child;

  /// Height of each fade gradient.
  final double size;

  /// The solid color the gradient fades from (at the edge) to transparent.
  /// Defaults to a subtle black wash suited to light surfaces.
  final Color? color;

  const ScrollShadow({super.key, required this.child, this.size = 16, this.color});

  @override
  State<ScrollShadow> createState() => _ScrollShadowState();
}

class _ScrollShadowState extends State<ScrollShadow> {
  // 0..1 opacity for each edge shadow, derived from how far the nearest content
  // is scrolled past that edge (clamped to [size] so it fades in over the first
  // [size] pixels of overscrollable content, then holds full strength).
  double _top = 0;
  double _bottom = 0;

  bool _onScroll(ScrollNotification notification) {
    final m = notification.metrics;
    if (m.axis != Axis.vertical) return false;
    final top = ((m.pixels - m.minScrollExtent) / widget.size).clamp(0.0, 1.0);
    final bottom = ((m.maxScrollExtent - m.pixels) / widget.size).clamp(0.0, 1.0);
    if (top != _top || bottom != _bottom) {
      setState(() {
        _top = top;
        _bottom = bottom;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0x1A000000);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          widget.child,
          Positioned(top: 0, left: 0, right: 0, child: _edge(color, top: true, opacity: _top)),
          Positioned(bottom: 0, left: 0, right: 0, child: _edge(color, top: false, opacity: _bottom)),
        ],
      ),
    );
  }

  Widget _edge(Color color, {required bool top, required double opacity}) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Container(
          height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
