import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/board_settings_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/eraser_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/pen_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/toggle_button_toolbar.dart';
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
              ToolButton(icon: LucideIcons.undo, title: context.localizations.toolToolbar_undo, onPressed: null),
              ToolButton(icon: LucideIcons.redo, title: context.localizations.toolToolbar_redo, onPressed: null),
              ToolButton(icon: LucideIcons.trash2, title: context.localizations.toolToolbar_clear, onPressed: controller.onClearButtonPressed),
            ],
          ),
          ToggleButtonToolbar(
            buttons: [
              PenToolButton(viewModel: viewModel, controller: controller),
              EraserToolButton(viewModel: viewModel, controller: controller),
              ToolButton(icon: LucideIcons.ellipsis, title: context.localizations.toolToolbar_widgets, onPressed: null),
              BoardSettingsButton(viewModel: viewModel, controller: controller),
            ],
          ),
        ],
      ),
    );
  }

}
