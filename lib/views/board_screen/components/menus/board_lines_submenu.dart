part of '../buttons/board_settings_button.dart';

final List<Color> _boardLineColorPresets = [Colors.black, Colors.white, Colors.grey[100], Colors.errorPrimaryColor];

MenuFlyoutSubItem _boardLinesSubmenu(BuildContext context, BoardScreenViewModel viewModel, BoardScreenController controller) {
  return MenuFlyoutSubItem(
    leading: Icon(LucideIcons.grid2x2),
    text: Text(context.localizations.boardLinesSubmenu_title),
    items: (context) => [
      MenuFlyoutItem(
        onPressed: null,
        text: Observer(
          builder: (_) {
            return Column(
              crossAxisAlignment: .start,
              spacing: 8,
              mainAxisSize: .min,
              children: [
                Row(
                  spacing: 8,
                  mainAxisSize: .min,
                  children: [
                    ToggleButton(
                      checked: viewModel.board.linePattern == .none,
                      onChanged: (_) => controller.onBoardLinePatternPicked(.none),
                      child: Icon(LucideIcons.square, size: 24),
                    ),
                    ToggleButton(
                      checked: viewModel.board.linePattern == .horizontal,
                      onChanged: (_) => controller.onBoardLinePatternPicked(.horizontal),
                      child: Icon(LucideIcons.rows3, size: 24),
                    ),
                    ToggleButton(
                      checked: viewModel.board.linePattern == .grid,
                      onChanged: (_) => controller.onBoardLinePatternPicked(.grid),
                      child: Icon(LucideIcons.grid2x2, size: 24),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      MenuFlyoutItem(
        onPressed: null,
        text: Observer(builder: (context) => Row(
          mainAxisSize: .min,
          children: [
            Icon(LucideIcons.grid3x3),
            SizedBox(
              height: 24,
              child: Slider(
                min: 32,
                max: 128,
                value: viewModel.board.lineSpacing,
                onChanged: viewModel.board.linePattern != .none ? controller.onBoardLineSpacingSliderMoved : null,
                onChangeEnd: viewModel.board.linePattern != .none ? controller.onBoardLineSpacingSliderEnd : null,
              ),
            ),
            Icon(LucideIcons.grid2x2),
          ],
        ),
      )),
      MenuFlyoutItem(
        onPressed: null,
        text: Observer(builder: (context) => Row(
          mainAxisSize: .min,
          spacing: 8,
          children: _boardLineColorPresets.map((color) =>
            ColorPresetButton(
              color: color,
              isActive: viewModel.board.lineColor == color,
              onPressed: () => controller.onBoardLineColorPicked(color),
            ),
          ).toList(),
        )),
      ),
    ],
  );
}
