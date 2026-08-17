import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The gap kept between the blown-up widget and the edges of its surface.
const double _kFullScreenGap = 32;

/// Edge of the close button, and the strip reserved for it.
const double _kCloseButtonSize = 44;

/// One board widget filling the screen, upright and as large as fits.
///
/// The same view on both sides of the live-share protocol: the presenter pushes
/// it as a route (interactive, with a close button, over the route's own
/// barrier), every mirror renders it inside its board canvas (read-only,
/// painting its own scrim since it has no [ModalBarrier]).
///
/// Rotation is deliberately dropped. A widget is turned to suit where it sits
/// on the board, which says nothing about how it should be read when it *is*
/// the screen — and a rotated widget would have to shrink to fit its own
/// bounding box.
class FullScreenWidgetView extends StatelessWidget {

  final BoardWidgetConfig config;

  /// Persists config the widget changes about itself (a to-do ticked, a timer
  /// started). null makes the view read-only — a mirror shows what the
  /// presenter is doing and takes no input of its own.
  final ValueChanged<BoardWidgetConfig>? onConfigChanged;

  /// Shows the close button when non-null. Mirrors leave it off: only the
  /// presenter can leave the mode.
  final VoidCallback? onClose;

  /// Whether to paint the dimming scrim under the widget. Routes leave this
  /// false — their [ModalBarrier] already paints it, and painting a second one
  /// here would also swallow the taps that dismiss it.
  final bool paintScrim;

  const FullScreenWidgetView({
    super.key,
    required this.config,
    this.onConfigChanged,
    this.onClose,
    this.paintScrim = false,
  });

  @override
  Widget build(BuildContext context) {
    final onConfigChanged = this.onConfigChanged;
    final onClose = this.onClose;
    final size = descriptorFor(config).naturalSize(config);
    // The close button's strip is reserved at the top *and* bottom so the
    // widget stays centred on the screen rather than sitting low under it.
    final vertical = _kFullScreenGap + (onClose == null ? 0 : _kCloseButtonSize + _kFullScreenGap);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (paintScrim) const ColoredBox(color: kAppBarrierColor),
        // Nothing here is opaque to hit-testing outside the widget's own box:
        // a FittedBox tests only its child, so taps beside the widget fall
        // through to the barrier that dismisses the route.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _kFullScreenGap, vertical: vertical),
          child: IgnorePointer(
            ignoring: onConfigChanged == null,
            child: FittedBox(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: descriptorFor(config).buildWidget(config, onConfigChanged ?? (_) {}),
              ),
            ),
          ),
        ),
        if (onClose != null)
          Positioned(
            top: _kFullScreenGap,
            right: _kFullScreenGap,
            child: _CloseButton(onTap: onClose),
          ),
      ],
    );
  }

}

/// Leaves the full-screen mode. Styled for the dark scrim it sits on rather
/// than reusing the widget header's button, which is drawn for a light bar.
class _CloseButton extends StatefulWidget {

  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();

}

class _CloseButtonState extends State<_CloseButton> {

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.localizations.boardWidget_exitFullScreen,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _kCloseButtonSize,
            height: _kCloseButtonSize,
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: _hovered ? 0.22 : 0.10),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(kShortControlCornerRadius),
              ),
            ),
            child: Icon(
              LucideIcons.x,
              size: 22,
              color: Colors.white.withValues(alpha: _hovered ? 1 : 0.85),
            ),
          ),
        ),
      ),
    );
  }

}

/// A live-share receiver's half of the full-screen mode: blurs the mirrored
/// board and shows [boardWidget] over it, or nothing when the presenter isn't
/// presenting one.
///
/// Drives [BlurredBackdropTransition] off its own controller because there is no
/// route here to borrow an animation from — which is also why it holds on to the
/// last widget it was given: the fade-out still has to draw something after the
/// presenter has already left the mode.
class MirroredFullScreenWidget extends StatefulWidget {

  final BoardWidget? boardWidget;

  const MirroredFullScreenWidget({super.key, required this.boardWidget});

  @override
  State<MirroredFullScreenWidget> createState() => _MirroredFullScreenWidgetState();

}

class _MirroredFullScreenWidgetState extends State<MirroredFullScreenWidget> with SingleTickerProviderStateMixin {

  // Matches the entrance the presenter's route gets from fluent, so the same
  // change reads the same on the board and on every mirror of it.
  static const Duration _duration = Duration(milliseconds: 300);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _duration)..addStatusListener(_onStatus);

  /// What to draw: the current widget, or — while fading out — the last one.
  BoardWidget? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.boardWidget;
    if (_shown != null) _controller.forward();
  }

  @override
  void didUpdateWidget(MirroredFullScreenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final boardWidget = widget.boardWidget;
    if (boardWidget != null) {
      // Assigned rather than setState'd: this rebuild is already under way. Every
      // delta to the widget arrives here too — a stopwatch shown full screen ticks
      // through this path — as does the presenter switching straight from one
      // widget to another, which replaces the old one without a trip through
      // nothing.
      _shown = boardWidget;
      _controller.forward();
    } else if (oldWidget.boardWidget != null) {
      _controller.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    // Fully out: drop the widget so its body stops running behind an invisible
    // layer (a mirrored stopwatch keeps ticking on the board itself).
    if (status == AnimationStatus.dismissed && mounted) setState(() => _shown = null);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    return BlurredBackdropTransition(
      animation: _controller,
      blurAmount: context.appTheme.dialogs.barrierBlur,
      child: FullScreenWidgetView(config: shown.config, paintScrim: true),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

}
