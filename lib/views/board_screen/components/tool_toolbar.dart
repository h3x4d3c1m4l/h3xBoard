import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/board_screen/components/toggle_button_toolbar.dart';
import 'package:h3xboard/views/board_screen/components/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum SelectableEditTool { pen, eraser }

class ToolToolbar extends StatelessWidget {

  final SelectableEditTool activeTool;
  final ValueChanged<SelectableEditTool> onSelectableToolButtonPressed;
  final VoidCallback onClearButtonPressed;

  const ToolToolbar({
    super.key,
    required this.activeTool,
    required this.onSelectableToolButtonPressed,
    required this.onClearButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 32,
      children: [
        ToggleButtonToolbar(
          buttons: [
            ToolButton(icon: LucideIcons.undo, title: 'Undo', onPressed: null),
            ToolButton(icon: LucideIcons.redo, title: 'Redo', onPressed: null),
            ToolButton(icon: LucideIcons.trash2, title: 'Clear', onPressed: onClearButtonPressed),
          ],
        ),
        ToggleButtonToolbar(
          buttons: [
            ToolButton(
              icon: LucideIcons.pen,
              title: 'Draw',
              checked: activeTool == .pen,
              onPressed: () => onSelectableToolButtonPressed(.pen),
              flyout: Text("<Placeholder for pen size>"),
            ),
            ToolButton(icon: LucideIcons.eraser, title: 'Erase', checked: activeTool == .eraser, onPressed: () => onSelectableToolButtonPressed(.eraser)),
            ToolButton(icon: LucideIcons.ellipsis, title: 'Widgets', onPressed: null),
          ],
        ),
      ],
    );
  }

}
