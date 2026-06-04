part of '../buttons/board_settings_button.dart';

MenuFlyoutItem _fullscreenMenuItem(BuildContext context, BoardScreenViewModel viewModel, BoardScreenController controller) {
  return MenuFlyoutItem(
    leading: Observer(
      builder: (_) => Icon(viewModel.isFullscreen ? LucideIcons.minimize : LucideIcons.maximize),
    ),
    text: Observer(
      builder: (_) => Text(
        viewModel.isFullscreen
            ? context.localizations.boardSettingsButton_exitFullscreen
            : context.localizations.boardSettingsButton_fullscreen,
      ),
    ),
    onPressed: () => controller.onFullscreenToggle(),
  );
}
