import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/add_widget_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/eraser_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/markup_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/pen_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/pointer_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/text_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/bar_scroll_area.dart';
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
    // No outer padding here: BoardScaffold owns the spacing between a bar and the
    // board, so the same gap applies to every bar whether it is docked inside or
    // outside. `toolbarPadding` is the bar's *inner* padding around its buttons.
    return Observer(
      builder: (context) => DecoratedBox(
        decoration: context.appTheme.surfaces.toolbar,
        child: Padding(
          padding: context.appTheme.surfaces.toolbarPadding,
          child: BarScrollArea(
            direction: direction,
            // The bar's own surface, so the ends dissolve into it.
            fadeColor: context.appTheme.surfaces.toolbar.color,
            child: Flex(
              direction: direction,
              mainAxisSize: MainAxisSize.min,
              children: [
                ToggleButtonToolbar(
                  direction: direction,
                  buttons: [
                    PointerToolButton(viewModel: viewModel, controller: controller),
                    PenToolButton(viewModel: viewModel, controller: controller),
                    MarkupToolButton(viewModel: viewModel, controller: controller),
                    TextToolButton(controller: controller),
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
        // MUST stay below the tool buttons' own height, or it becomes the bar's
        // height floor instead of a separator.
        size: 36,
        style: const DividerThemeData(
          verticalMargin: EdgeInsets.zero,
          horizontalMargin: EdgeInsets.zero,
        ),
      ),
    );
  }

}
