import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/settings_dialog.dart';
import 'package:h3xboard/views/components/flyouts/app_menu_flyout.dart';
import 'package:h3xboard/views/components/flyouts/continuous_menu_flyout.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Bare hamburger icon that opens the settings menu as a flyout.
class MenuButton extends StatefulWidget {

  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  const MenuButton({super.key, required this.controller, required this.viewModel});

  @override
  State<MenuButton> createState() => _MenuButtonState();

}

class _MenuButtonState extends State<MenuButton> {

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
