import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/add_widget_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/eraser_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/pen_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/pointer_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/toggle_button_toolbar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ToolToolbar extends StatelessWidget {

  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  /// The bar's layout axis. Horizontal (default) when docked top/bottom; vertical
  /// when docked left/right.
  final Axis direction;

  const ToolToolbar({
    super.key,
    required this.controller,
    required this.viewModel,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Observer(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: theme.micaBackgroundColor,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: BorderSide(color: theme.resources.cardStrokeColorDefault),
            ),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Flex(
              direction: direction,
              mainAxisSize: MainAxisSize.min,
              children: [
                ToggleButtonToolbar(
                  direction: direction,
                  buttons: [
                    PointerToolButton(viewModel: viewModel, controller: controller),
                    PenToolButton(viewModel: viewModel, controller: controller),
                    EraserToolButton(viewModel: viewModel, controller: controller),
                  ],
                ),
                _ToolbarDivider(direction: direction),
                ToggleButtonToolbar(
                  direction: direction,
                  buttons: [
                    ToolButton(icon: LucideIcons.undo, title: context.localizations.toolToolbar_undo, onPressed: controller.historyManager.canUndo ? controller.historyManager.undo : null),
                    ToolButton(icon: LucideIcons.redo, title: context.localizations.toolToolbar_redo, onPressed: controller.historyManager.canRedo ? controller.historyManager.redo : null),
                    ToolButton(icon: LucideIcons.trash2, title: context.localizations.toolToolbar_clear, onPressed: controller.onClearButtonPressed),
                  ],
                ),
                _ToolbarDivider(direction: direction),
                ToggleButtonToolbar(
                  direction: direction,
                  buttons: [
                    AddWidgetButton(controller: controller),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _ToolbarDivider extends StatelessWidget {

  /// The toolbar's own axis; the divider runs across it.
  final Axis direction;

  const _ToolbarDivider({required this.direction});

  @override
  Widget build(BuildContext context) {
    final isHorizontal = direction == Axis.horizontal;
    return Padding(
      padding: isHorizontal
          ? const EdgeInsets.symmetric(horizontal: 8)
          : const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        direction: isHorizontal ? Axis.vertical : Axis.horizontal,
        size: 48,
        style: const DividerThemeData(
          verticalMargin: EdgeInsets.zero,
          horizontalMargin: EdgeInsets.zero,
        ),
      ),
    );
  }

}
