import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Toolbar button that opens the board-settings dialog (board color, background
/// image and grid lines). Replaces the old settings flyout.
class BoardSettingsButton extends StatelessWidget {

  final BoardScreenController controller;

  const BoardSettingsButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ToolButton(
      icon: LucideIcons.settings,
      title: context.localizations.boardSettingsButton_settings,
      onPressed: () => unawaited(controller.onShowBoardSettings()),
    );
  }

}
