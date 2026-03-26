import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/toggle_button_toolbar.dart';
import 'package:h3xboard/views/board_screen/components/tool_button.dart';
import 'package:h3xboard/views/board_screen/components/toolbar_buttons/eraser_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/toolbar_buttons/pen_tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum SelectableEditTool { pen, eraser }

class ToolToolbar extends StatelessWidget {
  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  const ToolToolbar({super.key, required this.controller, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 32,
        children: [
          ToggleButtonToolbar(
            buttons: [
              ToolButton(icon: LucideIcons.undo, title: 'Undo', onPressed: null),
              ToolButton(icon: LucideIcons.redo, title: 'Redo', onPressed: null),
              ToolButton(icon: LucideIcons.trash2, title: 'Clear', onPressed: controller.onClearButtonPressed),
            ],
          ),
          ToggleButtonToolbar(
            buttons: [
              PenToolButton(viewModel: viewModel, controller: controller),
              EraserToolButton(viewModel: viewModel, controller: controller),
              ToolButton(icon: LucideIcons.ellipsis, title: 'Widgets', onPressed: null),
            ],
          ),
        ],
      ),
    );
  }
}
