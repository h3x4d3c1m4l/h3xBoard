import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Cloud glyph reporting where the autosave stands. A board opens already
/// persisted, so this is visible from the first frame; it only ever swaps
/// glyphs, never appears or disappears, and the controls beside it never shift.
class SaveStatusIndicator extends StatelessWidget {

  /// The icon size the neighbouring [IconButton]s use. Together with
  /// [kIconControlPadding] — what the app theme gives every icon button — this
  /// reproduces their exact rendered box, so the indicator occupies the same
  /// slot as the controls beside it.
  static const double _neighbourIconSize = 20;

  final BoardSaveStatus status;

  const SaveStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final loc = context.localizations;

    final (IconData icon, String label, Color color) = switch (status) {
      BoardSaveStatus.saving => (LucideIcons.cloud, loc.boardScreen_saving, theme.inactiveColor),
      BoardSaveStatus.saved => (LucideIcons.cloudCheck, loc.boardScreen_saved, theme.inactiveColor),
      BoardSaveStatus.error => (LucideIcons.cloudAlert, loc.boardScreen_saveError, Colors.red),
    };

    return Tooltip(
      message: label,
      child: SizedBox(
        width: kIconControlPadding.horizontal + _neighbourIconSize,
        height: kIconControlPadding.vertical + _neighbourIconSize,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(icon, key: ValueKey(icon), size: 16, color: color),
          ),
        ),
      ),
    );
  }

}
