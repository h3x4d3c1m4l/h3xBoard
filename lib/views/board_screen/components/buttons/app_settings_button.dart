import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/settings_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Toolbar button that opens the app-wide Settings dialog (language, bar
/// placement). Distinct from [BoardSettingsButton], which edits the current
/// board's appearance.
class AppSettingsButton extends StatelessWidget {

  const AppSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ToolButton(
      icon: LucideIcons.slidersHorizontal,
      title: context.localizations.appSettingsButton_preferences,
      onPressed: () => unawaited(showSettingsDialog(context)),
    );
  }

}
