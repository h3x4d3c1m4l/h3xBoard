import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/color_preset_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

part '../menus/board_color_submenu.dart';
part '../menus/board_lines_submenu.dart';

class BoardSettingsButton extends StatefulWidget {

  final BoardScreenViewModel viewModel;
  final BoardScreenController controller;

  const BoardSettingsButton({super.key, required this.viewModel, required this.controller});

  @override
  State<BoardSettingsButton> createState() => _BoardSettingsButtonState();

}

class _BoardSettingsButtonState extends State<BoardSettingsButton> {

  final FlyoutController _menuController = FlyoutController();

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => ToolButton(
        icon: LucideIcons.settings,
        title: 'Settings',
        onPressed: () {},
        flyoutBuilder: (context) => Observer(
          builder: (context) => MenuFlyout(
            items: [
              _boardColorSubmenu(widget.viewModel, widget.controller),
              _boardLinesSubmenu(widget.viewModel, widget.controller),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

}
