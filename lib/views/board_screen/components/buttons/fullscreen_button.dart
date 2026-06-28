import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Toolbar button that toggles fullscreen, reflecting the current state with its
/// icon and label. Moved out of the old settings flyout into its own button.
class FullscreenButton extends StatelessWidget {

  final BoardScreenViewModel viewModel;
  final BoardScreenController controller;

  const FullscreenButton({super.key, required this.viewModel, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => ToolButton(
        icon: viewModel.isFullscreen ? LucideIcons.minimize : LucideIcons.maximize,
        title: viewModel.isFullscreen
            ? context.localizations.boardSettingsButton_exitFullscreen
            : context.localizations.boardSettingsButton_fullscreen,
        onPressed: controller.onFullscreenToggle,
      ),
    );
  }

}
