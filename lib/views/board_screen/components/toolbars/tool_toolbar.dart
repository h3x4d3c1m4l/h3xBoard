import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/add_widget_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/board_settings_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/eraser_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/pen_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/pointer_tool_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/toggle_button_toolbar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ToolToolbar extends StatelessWidget {

  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  const ToolToolbar({super.key, required this.controller, required this.viewModel});

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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ToolButton(
                  icon: LucideIcons.x,
                  title: context.localizations.toolToolbar_close,
                  onPressed: () => unawaited(controller.requestClose()),
                ),
                const _ToolbarDivider(),
                ToggleButtonToolbar(
                  buttons: [
                    PointerToolButton(viewModel: viewModel, controller: controller),
                    PenToolButton(viewModel: viewModel, controller: controller),
                    EraserToolButton(viewModel: viewModel, controller: controller),
                  ],
                ),
                const _ToolbarDivider(),
                ToggleButtonToolbar(
                  buttons: [
                    ToolButton(icon: LucideIcons.undo, title: context.localizations.toolToolbar_undo, onPressed: controller.historyManager.canUndo ? controller.historyManager.undo : null),
                    ToolButton(icon: LucideIcons.redo, title: context.localizations.toolToolbar_redo, onPressed: controller.historyManager.canRedo ? controller.historyManager.redo : null),
                    ToolButton(icon: LucideIcons.trash2, title: context.localizations.toolToolbar_clear, onPressed: controller.onClearButtonPressed),
                  ],
                ),
                const _ToolbarDivider(),
                ToggleButtonToolbar(
                  buttons: [
                    AddWidgetButton(controller: controller),
                    BoardSettingsButton(viewModel: viewModel, controller: controller),
                  ],
                ),
                const _ToolbarDivider(),
                _SaveStatusIndicator(status: viewModel.saveStatus),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _ToolbarDivider extends StatelessWidget {

  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Divider(
        direction: Axis.vertical,
        size: 48,
        style: DividerThemeData(verticalMargin: EdgeInsets.zero),
      ),
    );
  }

}

class _SaveStatusIndicator extends StatelessWidget {

  final BoardSaveStatus status;

  const _SaveStatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final loc = context.localizations;

    final (IconData icon, String label, Color color) = switch (status) {
      BoardSaveStatus.idle => (LucideIcons.cloud, '', theme.inactiveColor),
      BoardSaveStatus.saving => (LucideIcons.cloud, loc.boardScreen_saving, theme.inactiveColor),
      BoardSaveStatus.saved => (LucideIcons.cloudCheck, loc.boardScreen_saved, theme.inactiveColor),
      BoardSaveStatus.error => (LucideIcons.cloudAlert, loc.boardScreen_saveError, Colors.red),
    };

    return AnimatedOpacity(
      opacity: status == BoardSaveStatus.idle ? 0 : 1,
      duration: const Duration(milliseconds: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(icon, size: 16, color: color),
          Text(label, style: theme.typography.caption?.copyWith(color: color)),
        ],
      ),
    );
  }

}
