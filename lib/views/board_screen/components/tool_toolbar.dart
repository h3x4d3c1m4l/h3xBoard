import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/board_screen/components/toggle_button_toolbar.dart';
import 'package:h3xboard/views/board_screen/components/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ToolToolbar extends StatelessWidget {

  const ToolToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return ToggleButtonToolbar(
      buttons: [
        ToolButton(icon: LucideIcons.pen, title: 'Draw', checked: false, onPressed: () {}),
        ToolButton(icon: LucideIcons.eraser, title: 'Erase', checked: true, onPressed: () {}),
        ToolButton(icon: LucideIcons.ellipsis, title: 'Widgets', checked: false, onPressed: () {}),
      ],
    );
  }

}
