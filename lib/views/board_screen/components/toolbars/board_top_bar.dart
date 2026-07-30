import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/laser_pointer.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/services/live_share/board_mirroring.dart';
import 'package:h3xboard/services/live_share/live_share_session_service.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/settings_dialog.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/share_dialog.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/sub_board_tab_bar.dart';
import 'package:h3xboard/views/components/flyouts/app_menu_flyout.dart';
import 'package:h3xboard/views/components/flyouts/continuous_menu_flyout.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The board screen's top bar: an Exit button on the left, the sub-board switcher
/// centred, and the save indicator + menu on the right. Styled to match the
/// Boards screen header (card background with a bottom hairline).
class BoardTopBar extends StatelessWidget {

  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  const BoardTopBar({super.key, required this.controller, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        border: Border(
          bottom: BorderSide(color: theme.resources.controlStrokeColorDefault),
        ),
      ),
      // Gutter + max-width constraint mirror the Boards screen so both top bars
      // line up with the board grid's content width.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kContentHorizontalPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _BalancedSide(
                    alignment: AlignmentDirectional.centerStart,
                    counterweight: _MenuControls(controller: controller, viewModel: viewModel),
                    child: _ExitButton(controller: controller),
                  ),
                  // The sub-board switcher fills the space between the fixed exit
                  // button and menu controls, and stays centred within it. When
                  // there are too many tabs it collapses the overflow behind a
                  // "more" button instead of pushing the bar wider.
                  Expanded(
                    child: Container(
                      margin: .symmetric(horizontal: 64),
                      alignment: .center,
                      child: Observer(
                        builder: (_) => SubBoardTabBar(
                          subBoards: viewModel.subBoards.toList(),
                          activeSubBoardId: viewModel.activeSubBoardId,
                          onSwitchSubBoard: controller.onSwitchSubBoard,
                          onAddSubBoard: controller.onAddSubBoard,
                          onRemoveSubBoard: controller.onRemoveSubBoard,
                          onRenameSubBoard: controller.onRenameSubBoard,
                        ),
                      ),
                    ),
                  ),
                  _BalancedSide(
                    alignment: AlignmentDirectional.centerEnd,
                    counterweight: _ExitButton(controller: controller),
                    child: _MenuControls(controller: controller, viewModel: viewModel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

/// A side slot of the top bar, sized to whichever side is wider: [child] is
/// rendered on top of an invisible [counterweight] (the *other* side's content),
/// so both slots end up equally wide and the Expanded centre between them is
/// truly centred in the bar.
class _BalancedSide extends StatelessWidget {

  final AlignmentGeometry alignment;
  final Widget counterweight;
  final Widget child;

  const _BalancedSide({required this.alignment, required this.counterweight, required this.child});

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

/// Arrow + "Exit" label. Routes through the controller (like every other exit)
/// so pending changes are flushed first.
class _ExitButton extends StatelessWidget {

  final BoardScreenController controller;

  const _ExitButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Button(
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6)),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
      onPressed: () => unawaited(controller.requestClose()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          const Icon(LucideIcons.arrowLeft, size: 18),
          Text(context.localizations.boardTopBar_exit),
        ],
      ),
    );
  }

}

/// Save indicator + vertical divider + hamburger menu, shown at the top-right.
class _MenuControls extends StatelessWidget {

  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  const _MenuControls({required this.controller, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        // Only while the board is actually being mirrored: a dot nobody else
        // can see points at nothing.
        Observer(
          builder: (_) => isBoardMirrored
              ? _LaserControl(controller: controller, viewModel: viewModel)
              : const SizedBox.shrink(),
        ),
        Observer(builder: (_) => _SaveStatusIndicator(status: viewModel.saveStatus)),
        const _ShareButton(),
        _MenuButton(controller: controller, viewModel: viewModel),
      ],
    );
  }

}

/// The laser pointer: one button that arms the laser and offers its colours in
/// the same tap. It sits with the share button because it is a presenting
/// control, not a drawing tool — keeping it out of the tool toolbar is the
/// point, since a laser is momentary and a sixth toggle next to pen and eraser
/// is one you forget to switch back from.
///
/// Arming opens the colour popup, but it is an offer rather than a step: point
/// at anything and it gets out of the way, exactly like the pen's width popup
/// stepping aside the moment a stroke starts. So it costs nothing to ignore,
/// which is what makes it safe to open unasked.
class _LaserControl extends StatefulWidget {

  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  const _LaserControl({required this.controller, required this.viewModel});

  @override
  State<_LaserControl> createState() => _LaserControlState();

}

class _LaserControlState extends State<_LaserControl> {

  final OverlayPortalController _popupController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  // A group id of this control's own, so tapping the button itself doesn't
  // register as a tap *outside* the popup and immediately close what the tap
  // just opened.
  final Object _tapGroupId = Object();

  @override
  void initState() {
    super.initState();
    // Any laser activity — the first point, or the dot being taken away on
    // disarm — retires the popup.
    widget.controller.laser.addListener(_hidePopup);
  }

  void _hidePopup() {
    if (mounted && _popupController.isShowing) _popupController.hide();
  }

  void _onPressed() {
    final arming = !widget.viewModel.laserArmed;
    widget.controller.setLaserArmed(arming);
    if (arming) {
      _popupController.show();
    } else {
      _hidePopup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = GetIt.I<AppSettingsController>();

    // Lit in the laser's own colour while armed, so the button and the dot on
    // the wall visibly belong together.
    final button = Tooltip(
      message: context.localizations.boardTopBar_laser,
      child: Observer(
        builder: (_) {
          final armed = widget.viewModel.laserArmed;
          final color = appSettings.laserColor.color;
          return IconButton(
            icon: Icon(
              LucideIcons.mousePointerClick,
              size: 20,
              color: armed ? color : null,
              shadows: armed ? [Shadow(color: color, blurRadius: 12)] : null,
            ),
            onPressed: _onPressed,
          );
        },
      ),
    );

    return OverlayPortal(
      controller: _popupController,
      // An OverlayPortal rather than a Flyout: a flyout takes a modal barrier,
      // which would swallow the very first point instead of letting it through
      // to the board and closing the popup on the way.
      overlayChildBuilder: (context) => Align(
        alignment: Alignment.topLeft,
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          offset: const Offset(0, 8),
          showWhenUnlinked: false,
          child: TapRegion(
            groupId: _tapGroupId,
            onTapOutside: (_) => _hidePopup(),
            child: _buildColorPopup(context),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: TapRegion(groupId: _tapGroupId, child: button),
      ),
    );
  }

  Widget _buildColorPopup(BuildContext context) {
    final appSettings = GetIt.I<AppSettingsController>();
    return FlyoutContent(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Observer(
        builder: (_) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(context.localizations.boardTopBar_laserColor),
            for (final laserColor in LaserColor.values)
              _LaserSwatch(
                laserColor: laserColor,
                label: _labelFor(context, laserColor),
                selected: laserColor == appSettings.laserColor,
                // Picking deliberately leaves the popup up: the next tap is as
                // likely to be a second opinion as it is to be done, and
                // pointing dismisses it anyway.
                onPressed: () => unawaited(widget.controller.onLaserColorPicked(laserColor)),
              ),
          ],
        ),
      ),
    );
  }

  String _labelFor(BuildContext context, LaserColor color) => switch (color) {
        LaserColor.red => context.localizations.laserColor_red,
        LaserColor.green => context.localizations.laserColor_green,
        LaserColor.blue => context.localizations.laserColor_blue,
        LaserColor.magenta => context.localizations.laserColor_magenta,
      };

  @override
  void dispose() {
    widget.controller.laser.removeListener(_hidePopup);
    super.dispose();
  }

}

/// One colour choice, drawn as a miniature of the dot it produces — coloured
/// bloom around a white-hot core — so the swatch previews the thing rather than
/// just naming it.
class _LaserSwatch extends StatelessWidget {

  final LaserColor laserColor;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _LaserSwatch({
    required this.laserColor,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = laserColor.color;
    return Tooltip(
      message: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? theme.accentColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8)],
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(Colors.white, color, 0.12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

/// Opens the live-share dialog. While sharing, a viewer-count badge sits on
/// the icon so the presenter always sees they are being watched.
class _ShareButton extends StatelessWidget {

  const _ShareButton();

  @override
  Widget build(BuildContext context) {
    final session = GetIt.I<LiveShareSessionService>();
    final theme = FluentTheme.of(context);
    return Tooltip(
      message: context.localizations.boardTopBar_share,
      child: Observer(
        builder: (_) => IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                LucideIcons.screenShare,
                size: 20,
                color: session.isSharing ? theme.accentColor : null,
              ),
              if (session.isSharing)
                Positioned(
                  top: -6,
                  right: -8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: Text(
                        '${session.viewerCount}',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => unawaited(showShareDialog(context)),
        ),
      ),
    );
  }

}

/// Bare hamburger icon that opens the settings menu as a flyout.
class _MenuButton extends StatefulWidget {

  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  const _MenuButton({required this.controller, required this.viewModel});

  @override
  State<_MenuButton> createState() => _MenuButtonState();

}

class _MenuButtonState extends State<_MenuButton> {

  final FlyoutController _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _openMenu() {
    // The State's context outlives the flyout, so use it for actions that open a
    // dialog after the flyout is dismissed (the flyout's own context is defunct
    // once popped).
    final rootContext = context;
    _flyoutController.showFlyout(
      builder: (context) => AppMenuFlyout(
        shape: continuousMenuShape(context),
        itemMargin: kMenuItemMargin,
        items: [
          MenuFlyoutItem(
            leading: Icon(widget.viewModel.isFullscreen ? LucideIcons.minimize : LucideIcons.maximize),
            text: Text(widget.viewModel.isFullscreen
                ? context.localizations.boardSettingsButton_exitFullscreen
                : context.localizations.boardSettingsButton_fullscreen),
            onPressed: () {
              Navigator.of(context).pop();
              widget.controller.onFullscreenToggle();
            },
          ),
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.settings),
            text: Text(context.localizations.boardSettingsButton_settings),
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(widget.controller.onShowBoardSettings());
            },
          ),
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.slidersHorizontal),
            text: Text(context.localizations.appSettingsButton_preferences),
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(showSettingsDialog(rootContext));
            },
          ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.layoutDashboard),
            text: Text(context.localizations.boardTopBar_boards),
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(widget.controller.requestClose());
            },
          ),
        ],
      ),
      placementMode: FlyoutPlacementMode.bottomRight,
      additionalOffset: 8,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.localizations.toolToolbar_menu,
      child: FlyoutTarget(
        controller: _flyoutController,
        child: IconButton(
          icon: const Icon(LucideIcons.menu, size: 20),
          onPressed: _openMenu,
        ),
      ),
    );
  }

}

class _SaveStatusIndicator extends StatelessWidget {

  final BoardSaveStatus status;

  const _SaveStatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final loc = context.localizations;

    final (IconData icon, String label, Color color) = switch (status) {
      BoardSaveStatus.idle => (LucideIcons.cloud, '', theme.inactiveColor),
      BoardSaveStatus.saving => (LucideIcons.cloud, loc.boardScreen_saving, theme.inactiveColor),
      BoardSaveStatus.saved => (LucideIcons.cloudCheck, loc.boardScreen_saved, theme.inactiveColor),
      BoardSaveStatus.error => (LucideIcons.cloudAlert, loc.boardScreen_saveError, Colors.red),
    };

    final indicator = AnimatedOpacity(
      opacity: status == BoardSaveStatus.idle ? 0 : 1,
      duration: const Duration(milliseconds: 150),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(icon, key: ValueKey(icon), size: 16, color: color),
          ),
        ),
      ),
    );

    if (label.isEmpty) return indicator;

    return Tooltip(
      message: label,
      child: indicator,
    );
  }

}
