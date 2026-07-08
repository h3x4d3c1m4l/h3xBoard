import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/settings_dialog.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/sub_board_tab_bar.dart';
import 'package:h3xboard/widgets/app_menu_flyout.dart';
import 'package:h3xboard/widgets/continuous_menu_flyout.dart';
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
                  _ExitButton(controller: controller),
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
                  _MenuControls(controller: controller, viewModel: viewModel),
                ],
              ),
            ),
          ),
        ),
      ),
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
        Observer(builder: (_) => _SaveStatusIndicator(status: viewModel.saveStatus)),
        _MenuButton(controller: controller, viewModel: viewModel),
      ],
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
