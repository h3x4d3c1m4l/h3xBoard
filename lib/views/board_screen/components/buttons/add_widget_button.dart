import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddWidgetButton extends StatelessWidget {

  final BoardScreenController controller;

  const AddWidgetButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations;
    return ToolButton(
      icon: LucideIcons.layoutGrid,
      title: localizations.toolToolbar_widgets,
      onPressed: controller.onShowWidgetCatalog,
    );
  }

}
