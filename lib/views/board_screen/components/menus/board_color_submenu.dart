part of '../buttons/board_settings_button.dart';

const List<Color> _regularBoardColors = [Colors.black, Colors.white];
const List<Color> _chalkboardColors = [Color(0xFF1F3A2E), Color(0xFF2B2F3A)];

MenuFlyoutSubItem _boardColorSubmenu(BuildContext context, BoardScreenViewModel viewModel, BoardScreenController controller) {
  return MenuFlyoutSubItem(
    leading: Icon(LucideIcons.paintBucket),
    text: Text(context.localizations.boardColorSubmenu_title),
    items: (context) => [
      MenuFlyoutItem(
        selected: true,
        text: Observer(
          builder: (_) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  spacing: 8,
                  mainAxisSize: MainAxisSize.min,
                  children: _regularBoardColors.map((color) => ColorPresetButton(
                    color: color,
                    isChalkboard: false,
                    isActive: viewModel.boardColor == color,
                    onPressed: () {
                      controller.onBoardBackgroundColorPicked(color, false);
                    },
                  )).toList(),
                ),
                Row(
                  spacing: 8,
                  mainAxisSize: MainAxisSize.min,
                  children: _chalkboardColors.map((color) => ColorPresetButton(
                    color: color,
                    isChalkboard: true,
                    isActive: viewModel.boardColor == color,
                    onPressed: () {
                      controller.onBoardBackgroundColorPicked(color, true);
                    },
                  )).toList(),
                ),
              ],
            );
          },
        ),
        onPressed: () {},
      ),
    ],
  );
}
