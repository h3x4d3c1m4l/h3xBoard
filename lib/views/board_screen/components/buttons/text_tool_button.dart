import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Drops a text label on the board. It sits with the annotation tools rather
/// than in the widget catalog because placing text is an act of annotation, not
/// of adding a piece of classroom furniture.
///
/// Unlike its neighbours this is an action, not a mode, so it has no `checked`
/// state — [ToolButton] renders it as a plain button.
class TextToolButton extends StatelessWidget {

  const TextToolButton({super.key, required this.controller});

  final BoardScreenController controller;

  @override
  Widget build(BuildContext context) {
    return ToolButton(
      icon: LucideIcons.type,
      title: context.localizations.textToolButton_text,
      onPressed: controller.onAddTextBox,
    );
  }

}
