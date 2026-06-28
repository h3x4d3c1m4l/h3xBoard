import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// The non-drawing "Select" mode: shows the widget header chrome so widgets can be
// moved, resized, configured and removed. Has no flyout — it's a plain toggle.
class PointerToolButton extends StatelessWidget {

  const PointerToolButton({super.key, required this.viewModel, required this.controller});

  final BoardScreenViewModel viewModel;
  final BoardScreenController controller;

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) => ToolButton(
      icon: LucideIcons.mousePointer2,
      title: context.localizations.pointerToolButton_select,
      checked: viewModel.drawingTools.activeTool == .pointer,
      onPressed: () => controller.onSelectableToolButtonPressed(.pointer),
    ));
  }

}
