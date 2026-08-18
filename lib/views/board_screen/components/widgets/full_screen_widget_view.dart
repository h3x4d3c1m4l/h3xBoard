import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The gap kept between the blown-up widget and the edges of its surface.
const double _kFullScreenGap = 32;

/// Edge of the close button, and the strip reserved for it.
const double _kCloseButtonSize = 44;

/// How long a widget takes to fly between the board and the screen.
///
/// Shared by the presenter's route and every mirror's controller, so the same
/// change reads the same everywhere. Longer than fluent's `fastAnimationDuration`
/// (167ms), which is tuned for a dialog fading in place rather than for a widget
/// crossing half the screen and growing several times over.
const Duration kFullScreenFlightDuration = Duration(milliseconds: 260);

/// Where the widget sits *right now* on the surface behind the full-screen view,
/// in that view's own coordinates, or null when it has no place to fly from (or
/// has just been deleted). Resolved per frame rather than captured once: an
/// editable widget opens the soft keyboard, which resizes the page under the
/// route and moves the board beneath it.
typedef FullScreenOrigin = ({Rect rect, double rotation})? Function();

/// One board widget filling the screen, upright and as large as fits.
///
/// The same view on both sides of the live-share protocol: the presenter pushes
/// it as a route (interactive, with a close button, over the route's own
/// barrier), every mirror renders it inside its board canvas (read-only,
/// painting its own scrim since it has no [ModalBarrier]).
///
/// With an [originOf] it flies: the widget travels from where it sits on the
/// board to the middle of the screen, through the same [PlacedBoardWidget] the
/// board itself draws with — so at the start of the flight the two are the same
/// pixels, and the copy on the board can be hidden for the whole trip without a
/// seam. Both ends are aspect-correct at the same ratio, so the lerped rect
/// never distorts the widget on the way.
///
/// Rotation is deliberately dropped. A widget is turned to suit where it sits
/// on the board, which says nothing about how it should be read when it *is*
/// the screen — and a rotated widget would have to shrink to fit its own
/// bounding box. The flight unwinds it instead of snapping it.
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

  /// Drives the flight and the fade of everything around it. Defaults to
  /// "arrived", so a caller with nothing to animate gets the settled view.
  final Animation<double> animation;

  /// Where to fly from; null lands the widget straight at its full-screen place.
  final FullScreenOrigin? originOf;

  const FullScreenWidgetView({
    super.key,
    required this.config,
    this.onConfigChanged,
    this.onClose,
    this.paintScrim = false,
    this.animation = kAlwaysCompleteAnimation,
    this.originOf,
  });

  /// Angle folded back into a single turn. Rotation accumulates raw on the
  /// board, so a widget can carry several revolutions — which the flight would
  /// otherwise spend its 260ms unwinding.
  static double _singleTurn(double radians) => math.atan2(math.sin(radians), math.cos(radians));

  /// Where the widget ends up: its natural size fitted into what is left of
  /// [available] once the gap (and the close button's strip, reserved top *and*
  /// bottom so the widget stays centred) is taken off.
  static Rect _targetRect(Size available, Size naturalSize, {required bool hasClose}) {
    final vertical = _kFullScreenGap + (hasClose ? _kCloseButtonSize + _kFullScreenGap : 0);
    final box = Rect.fromLTWH(
      _kFullScreenGap,
      vertical,
      math.max(0, available.width - _kFullScreenGap * 2),
      math.max(0, available.height - vertical * 2),
    );
    return Alignment.center.inscribe(applyBoxFit(BoxFit.contain, naturalSize, box.size).destination, box);
  }

  @override
  Widget build(BuildContext context) {
    final onConfigChanged = this.onConfigChanged;
    final onClose = this.onClose;
    final naturalSize = descriptorFor(config).naturalSize(config);
    // Read-only on mirrors; the one IgnorePointer this view is allowed to have.
    final body = IgnorePointer(
      ignoring: onConfigChanged == null,
      child: descriptorFor(config).buildWidget(config, onConfigChanged ?? (_) {}),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final target = _targetRect(constraints.biggest, naturalSize, hasClose: onClose != null);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (paintScrim)
              FadeTransition(
                opacity: animation,
                child: const ColoredBox(color: kAppBarrierColor),
              ),
            // Nothing here is opaque to hit-testing outside the widget's own box:
            // the widget is placed by rect, so taps beside it fall through to the
            // barrier that dismisses the route.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: animation,
                child: body,
                builder: (context, child) {
                  final origin = originOf?.call();
                  final t = Curves.fastOutSlowIn.transform(animation.value.clamp(0.0, 1.0));
                  return Stack(
                    // A widget still part-turned mid-flight paints outside its own
                    // rect, and must not pick up a second clip on the way.
                    clipBehavior: Clip.none,
                    children: [
                      PlacedBoardWidget(
                        rect: origin == null ? target : Rect.lerp(origin.rect, target, t)!,
                        rotation: origin == null ? 0 : lerpDouble(_singleTurn(origin.rotation), 0, t)!,
                        naturalSize: naturalSize,
                        child: child!,
                      ),
                    ],
                  );
                },
              ),
            ),
            if (onClose != null)
              Positioned(
                top: _kFullScreenGap,
                right: _kFullScreenGap,
                child: FadeTransition(
                  opacity: animation,
                  child: _CloseButton(onTap: onClose),
                ),
              ),
          ],
        );
      },
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

/// A live-share receiver's board widgets, and the full-screen mode over them.
///
/// The two are one widget because they share a secret: which widget is being
/// blown up, and for how long. That outlives `fullScreenWidget != null` — the
/// flight back still has to draw something after the presenter has already left
/// the mode — so the loop cannot work it out from its own inputs, and the
/// overlay cannot report it upward without notifying an ancestor mid-build.
///
/// Everything here is in the mirror's 1920×1080 canvas space, which is why the
/// flight needs no coordinate mapping on this side: the widget's place on the
/// board and the middle of the screen are measured with the same ruler.
class MirroredBoardWidgets extends StatefulWidget {

  final List<BoardWidget> widgets;

  /// The widget the presenter is showing full screen; null when they aren't.
  final BoardWidget? fullScreenWidget;

  const MirroredBoardWidgets({
    super.key,
    required this.widgets,
    required this.fullScreenWidget,
  });

  @override
  State<MirroredBoardWidgets> createState() => _MirroredBoardWidgetsState();

}

class _MirroredBoardWidgetsState extends State<MirroredBoardWidgets> with SingleTickerProviderStateMixin {

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: kFullScreenFlightDuration)..addStatusListener(_onStatus);

  /// What to blow up: the current widget, or — while flying back — the last one.
  BoardWidget? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.fullScreenWidget;
    if (_shown != null) _controller.forward();
  }

  @override
  void didUpdateWidget(MirroredBoardWidgets oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fullScreenWidget = widget.fullScreenWidget;
    if (fullScreenWidget != null) {
      // Assigned rather than setState'd: this rebuild is already under way. Every
      // delta to the widget arrives here too — a stopwatch shown full screen ticks
      // through this path — as does the presenter switching straight from one
      // widget to another, which replaces the old one without a trip through
      // nothing.
      _shown = fullScreenWidget;
      _controller.forward();
    } else if (oldWidget.fullScreenWidget != null) {
      _controller.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    // Landed back on the board: drop the blown-up copy and let the board's own
    // copy show again.
    if (status == AnimationStatus.dismissed && mounted) setState(() => _shown = null);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Stack(
      children: [
        for (final bw in widget.widgets)
          ManipulableBoardWidget(
            key: ValueKey(bw.id),
            boardWidget: bw,
            // The copy being flown is kept laid out but unpainted, so the widget
            // is never on screen twice and never restarts on the way back.
            child: Opacity(
              opacity: bw.id == shown?.id ? 0 : 1,
              // Read-only mirror: widgets never edit their own config here.
              child: descriptorFor(bw.config).buildWidget(bw.config, (_) {}),
            ),
          ),
        if (shown != null)
          Positioned.fill(
            child: MirroredFullScreenWidget(boardWidget: shown, animation: _controller),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

}

/// The blown-up half of [MirroredBoardWidgets]: blurs the mirrored board and
/// flies [boardWidget] up off it.
///
/// Blur without fade, unlike an ordinary dialog — the widget arrives from a real
/// place on the board, and fading it in from nothing would undo that.
class MirroredFullScreenWidget extends StatelessWidget {

  final BoardWidget boardWidget;
  final Animation<double> animation;

  const MirroredFullScreenWidget({
    super.key,
    required this.boardWidget,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return BlurredBackdrop(
      animation: animation,
      blurAmount: context.appTheme.dialogs.barrierBlur,
      child: FullScreenWidgetView(
        config: boardWidget.config,
        paintScrim: true,
        animation: animation,
        originOf: () => (
          rect: ManipulableBoardWidget.rectFor(boardWidget),
          rotation: boardWidget.rotation,
        ),
      ),
    );
  }

}
