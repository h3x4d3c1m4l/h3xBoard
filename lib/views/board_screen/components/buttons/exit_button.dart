import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Arrow + "Exit" label. Routes through the controller (like every other exit)
/// so pending changes are flushed first.
class ExitButton extends StatelessWidget {

  final BoardScreenController controller;

  const ExitButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Button(
      style: context.appTheme.buttons.exit,
      onPressed: () => unawaited(controller.requestClose()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          const Icon(LucideIcons.arrowLeft, size: 18),
          Text(context.localizations.boardTopBar_exit),
        ],
      ),
    );
  }

}
