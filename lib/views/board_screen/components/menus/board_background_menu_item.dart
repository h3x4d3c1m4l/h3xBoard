part of '../buttons/board_settings_button.dart';

MenuFlyoutItem _boardBackgroundMenuItem(BuildContext context, BoardScreenViewModel viewModel, BoardScreenController controller) {
  return MenuFlyoutItem(
    leading: const Icon(LucideIcons.image),
    text: Text(context.localizations.boardBackgroundMenuItem_title),
    onPressed: () => controller.onPickBackgroundImage(),
  );
}
