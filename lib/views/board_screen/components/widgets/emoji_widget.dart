import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/emoji_picker_dialog.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/emoji_image.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A single emoji dropped on the board as bare artwork.
///
/// Drawn from bundled Noto Emoji vector graphics rather than from a font, so it
/// looks identical on every platform. Being vector, it stays sharp at whatever
/// scale the user drags it to.
class EmojiWidget extends StatelessWidget {

  /// Square, because the artwork is authored on a square canvas.
  static const Size naturalSize = Size(220, 220);

  final String emoji;

  const EmojiWidget({super.key, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: naturalSize,
      child: EmojiImage(emoji: emoji, isScaled: true),
    );
  }

}

class EmojiWidgetDescriptor extends BoardWidgetDescriptor {

  static const EmojiWidgetDescriptor instance = EmojiWidgetDescriptor._();
  const EmojiWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.smile;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_emoji;

  @override
  Size naturalSize(BoardWidgetConfig config) => EmojiWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const EmojiConfig();

  // Bare artwork rather than a boxed widget: no header bar, dragged by its body,
  // and a tap brings out the resize/rotate handles the header would otherwise
  // toggle. Matches how the text label behaves.
  @override
  bool get hasHeaderBar => false;

  @override
  bool get isDraggableInSelectMode => true;

  @override
  bool get entersArrangeOnTap => true;

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as EmojiConfig;
    return EmojiWidget(emoji: c.emoji);
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.smile, size: 16),
        text: Text(context.localizations.emojiSettingsMenu_change),
        onPressed: () => _pickEmoji(context, config as EmojiConfig, onChange),
      ),
    ];
  }

  @override
  VoidCallback? editAction(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) =>
      () => _pickEmoji(context, config as EmojiConfig, onChange);

  static Future<void> _pickEmoji(
    BuildContext context,
    EmojiConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) async {
    final picked = await showAppDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => EmojiPickerDialog(selected: config.emoji),
    );
    if (picked == null) return;
    onChange(config.copyWith(emoji: picked));
  }

}
