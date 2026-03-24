import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/board_screen/components/toggle_button_toolbar.dart';
import 'package:h3xboard/views/board_screen/components/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum EditTool { pen, eraser, addWidget }

class ToolToolbar extends StatelessWidget {

  final EditTool activeTool;
  final ValueChanged<EditTool> onToolButtonPressed;

  const ToolToolbar({super.key, required this.activeTool, required this.onToolButtonPressed});

  @override
  Widget build(BuildContext context) {
    return ToggleButtonToolbar(
      buttons: [
        ToolButton(icon: LucideIcons.pen, title: 'Draw', checked: activeTool == .pen, onPressed: () => onToolButtonPressed(.pen)),
        ToolButton(icon: LucideIcons.eraser, title: 'Erase', checked: activeTool == .eraser, onPressed: () => onToolButtonPressed(.eraser)),
        ToolButton(icon: LucideIcons.ellipsis, title: 'Widgets', checked: activeTool == .addWidget, onPressed: () => onToolButtonPressed(.addWidget)),
      ],
    );
  }

}
