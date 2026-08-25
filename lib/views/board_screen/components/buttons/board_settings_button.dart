import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Opens the board's appearance settings (colour, background, lines).
///
/// Deliberately outside the tool toolbar: it changes the board itself rather
/// than what a tool does, so it is not one of the tools. It sits beside the bar
/// instead of in it — see [BalancedTrailing], which hangs it there without
/// pushing the bar off centre.
class BoardSettingsButton extends StatelessWidget {

  final BoardScreenController controller;

  const BoardSettingsButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.localizations.boardSettingsButton_settings,
      child: IconButton(
        icon: const Icon(LucideIcons.settings, size: 20),
        onPressed: () => unawaited(controller.onShowBoardSettings()),
      ),
    );
  }

}
