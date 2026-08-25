import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/services/emoji/ui_emoji_pack.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/emoji_image.dart';
import 'package:h3xboard/views/components/flyouts/app_menu_flyout.dart';
import 'package:h3xboard/views/components/flyouts/continuous_menu_flyout.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Size of a menu row's emoji. Matches the 16px icon fluent gives a
/// [MenuFlyoutItem]'s leading slot, which [EmojiImage] does not inherit — it is
/// vector artwork, not an [Icon], so [IconTheme] does not reach it.
const double _kMenuEmojiSize = 18;

/// Adds a widget to the board. Tapping opens a menu of every catalog widget, so
/// the common case — "put a timer on the board" — is one tap and one pick.
///
/// The full catalog dialog is still one row away: it is what offers live
/// previews and search, which a menu cannot.
class AddWidgetButton extends StatelessWidget {

  final BoardScreenController controller;

  const AddWidgetButton({super.key, required this.controller});

  // Alphabetical by localized label, so the order follows whatever language the
  // user is reading — the same ordering the catalog dialog uses.
  List<BoardWidgetDescriptor> _catalogDescriptors(AppLocalizations localizations) =>
      widgetRegistry.values.where((d) => d.showInCatalog).toList()
        ..sort((a, b) => a.label(localizations).toLowerCase().compareTo(b.label(localizations).toLowerCase()));

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations;
    return ToolButton(
      icon: LucideIcons.layoutGrid,
      title: localizations.toolToolbar_widgets,
      // The flyout does the work, but `onPressed: null` would read as a disabled
      // button and show the "not available" flyout instead.
      onPressed: () {},
      flyoutBuilder: (context) => AppMenuFlyout(
        shape: continuousMenuShape(context),
        itemMargin: kMenuItemMargin,
        items: [
          for (final descriptor in _catalogDescriptors(localizations))
            MenuFlyoutItem(
              leading: _MenuEmoji(emoji: descriptor.emoji),
              text: Text(descriptor.label(localizations)),
              onPressed: () => controller.onAddWidget(descriptor.defaultConfig),
            ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.layoutGrid),
            text: Text(localizations.addWidgetMenu_browseAll),
            onPressed: () => unawaited(controller.onShowWidgetCatalog()),
          ),
        ],
      ),
    );
  }

}

/// One menu row's emoji, drawn from the preloaded UI pack when it has arrived.
///
/// A null loader is the normal path before [UiEmojiPack.load] completes, and the
/// permanent path for a widget whose emoji predates the last `just gen-emoji`;
/// [EmojiImage] then reads the emoji's own asset, which costs a fetch but always
/// draws.
class _MenuEmoji extends StatelessWidget {

  final String emoji;

  const _MenuEmoji({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _kMenuEmojiSize,
      child: EmojiImage(emoji: emoji, loader: GetIt.I<UiEmojiPack>().loaderFor(emoji)),
    );
  }

}
