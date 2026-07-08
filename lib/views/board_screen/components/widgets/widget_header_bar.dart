import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';
import 'package:h3xboard/widgets/app_menu_flyout.dart';
import 'package:h3xboard/widgets/continuous_menu_flyout.dart';
import 'package:h3xboard/widgets/stable_flyout_controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Header dimensions in OS pixels. board.dart multiplies these by boardPixelRatio
// to obtain the canvas-space placement (see _headerPlacementFor), so rendering and
// hit-testing stay in sync.
const double kHeaderWidth = 250.0;
const double kHeaderHeight = 34.0;
const double kHeaderGap = 6.0; // gap between widget bounding box and header

// Matches the selection overlay accent colour.
const Color _kAccent = Color(0xFF3B82F6);
const Duration _kToggleAnim = Duration(milliseconds: 220);
// Fade the whole bar in/out as Select mode is toggled.
const Duration _kFadeAnim = Duration(milliseconds: 180);

// A persistent, always-visible chrome bar pinned above each board widget. In Use
// mode the whole bar is a drag handle (handled by the gesture layer in board.dart);
// the cog opens the settings menu and the manipulate toggle becomes a blue "Done"
// pill while arranging. The bar shares the widget's rotation and is rendered at a
// constant OS-pixel size regardless of widget scale: board.dart hands it a
// pre-computed canvas-space [center]/[size]/[rotation] and the content is scaled up
// via a FittedBox.
class WidgetHeaderBar extends StatelessWidget {

  final Offset center;
  final Size size;
  final double rotation;
  final Offset arrangeDelta;
  final String title;
  final bool isArranging;
  // Whether the board is in Select mode. The bar fades out (and stops absorbing
  // pointers) when false, rather than being removed, so the transition animates.
  final bool visible;
  final WidgetSettingsBuilder settingsBuilder;
  final VoidCallback onToggleArrange;
  final VoidCallback onClose;

  const WidgetHeaderBar({
    super.key,
    required this.center,
    required this.size,
    required this.rotation,
    required this.arrangeDelta,
    required this.title,
    required this.isArranging,
    required this.visible,
    required this.settingsBuilder,
    required this.onToggleArrange,
    required this.onClose,
  });

  // Keeps the header text upright: follows the widget's rotation but flips 180°
  // once past ±90° so the label never appears upside down. The bar's footprint is
  // symmetric under 180°, so this stays aligned with the board's hit-testing.
  double get _readableRotation {
    var a = rotation % (2 * math.pi);
    if (a > math.pi) a -= 2 * math.pi;
    if (a < -math.pi) a += 2 * math.pi;
    if (a > math.pi / 2) a -= math.pi;
    if (a < -math.pi / 2) a += math.pi;
    return a;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - size.width / 2,
      top: center.dy - size.height / 2,
      width: size.width,
      height: size.height,
      // Hidden bars must not absorb pointers (they'd block strokes underneath
      // while fading out), so gate hit-testing on visibility and fade opacity.
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: _kFadeAnim,
          curve: Curves.easeInOut,
          // The bar sits at its Use-mode anchor (instant, so it tracks drags) and eases
          // the extra Arrange push via the translate — animating the mode change only.
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: isArranging ? 1.0 : 0.0),
            duration: _kToggleAnim,
            curve: Curves.easeOut,
            builder: (context, t, child) => Transform.translate(offset: arrangeDelta * t, child: child),
            child: Transform.rotate(
              angle: _readableRotation,
              // Opaque so the header absorbs pointers and the drawing layer beneath it does
              // not receive strokes. The board's translucent gesture layer (above) still
              // gets the events to drive header drags, and the buttons handle their taps.
              child: Listener(
                behavior: HitTestBehavior.opaque,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: kHeaderWidth,
                    height: kHeaderHeight,
                    child: _buildContent(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          const Icon(LucideIcons.gripVertical, size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(width: 4),
          _HeaderSettingsButton(settingsBuilder: settingsBuilder),
          const SizedBox(width: 2),
          // Animate between the manipulate toggle and the Done pill.
          AnimatedSize(
            duration: _kToggleAnim,
            curve: Curves.easeOut,
            child: AnimatedSwitcher(
              duration: _kToggleAnim,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: isArranging
                  ? _DonePill(key: const ValueKey('done'), label: context.localizations.boardWidget_done, onTap: onToggleArrange)
                  : _HeaderIconButton(
                      key: const ValueKey('arrange'),
                      icon: LucideIcons.move,
                      tooltip: context.localizations.boardWidget_arrange,
                      onTap: onToggleArrange,
                    ),
            ),
          ),
          const SizedBox(width: 2),
          _HeaderIconButton(
            icon: LucideIcons.x,
            tooltip: context.localizations.boardWidget_remove,
            hoverColor: const Color(0xFFEF4444),
            onTap: onClose,
          ),
        ],
      ),
    );
  }

}

class _HeaderIconButton extends StatefulWidget {

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? hoverColor;

  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();

}

class _HeaderIconButtonState extends State<_HeaderIconButton> {

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? (widget.hoverColor ?? _kAccent) : const Color(0xFF475569);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hovered ? const Color(0x0F000000) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

}

// Cog button that opens the widget's settings menu (type-specific options, layers
// and visibility) as a flyout anchored to the header.
class _HeaderSettingsButton extends StatefulWidget {

  final WidgetSettingsBuilder settingsBuilder;

  const _HeaderSettingsButton({required this.settingsBuilder});

  @override
  State<_HeaderSettingsButton> createState() => _HeaderSettingsButtonState();

}

class _HeaderSettingsButtonState extends State<_HeaderSettingsButton> {

  final FlyoutController _flyoutController = StableFlyoutController();
  bool _hovered = false;

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _openSettings() {
    _flyoutController.showFlyout(
      builder: (context) => AppMenuFlyout(
        shape: continuousMenuShape(context),
        itemMargin: kMenuItemMargin,
        items: widget.settingsBuilder(context),
      ),
      placementMode: FlyoutPlacementMode.bottomCenter,
      additionalOffset: 8,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.localizations.boardWidget_settings,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FlyoutTarget(
          controller: _flyoutController,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openSettings,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _hovered ? const Color(0x0F000000) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(LucideIcons.settings, size: 16, color: _hovered ? _kAccent : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

}

class _DonePill extends StatelessWidget {

  final String label;
  final VoidCallback onTap;

  const _DonePill({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            // Match the resting background of a primary FilledButton exactly: it
            // uses the accent's brightness-adjusted brush, not the raw accentColor
            // (which is a different, lighter shade).
            color: theme.accentColor.defaultBrushFor(theme.brightness),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.check, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
