part of '../buttons/board_settings_button.dart';

final List<Color> _boardLineColorPresets = [Colors.black, Colors.white, Colors.grey[100], Colors.errorPrimaryColor];

MenuFlyoutSubItem _boardLinesSubmenu(BoardScreenViewModel viewModel, BoardScreenController controller) {
  return MenuFlyoutSubItem(
    leading: Icon(LucideIcons.grid2x2),
    text: const Text('Board lines:'),
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
                      checked: viewModel.boardLines == .none,
                      onChanged: (_) => controller.onBoardLinesPicked(.none),
                      child: Icon(LucideIcons.square, size: 24),
                    ),
                    ToggleButton(
                      checked: viewModel.boardLines == .horizontal,
                      onChanged: (_) => controller.onBoardLinesPicked(.horizontal),
                      child: Icon(LucideIcons.rows3, size: 24),
                    ),
                    ToggleButton(
                      checked: viewModel.boardLines == .grid,
                      onChanged: (_) => controller.onBoardLinesPicked(.grid),
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
                value: viewModel.boardLineDensity,
                onChanged: viewModel.boardLines != .none ? controller.onBoardLineDensitySliderMoved : null,
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
              isActive: viewModel.boardLinesColor == color,
              onPressed: () => controller.onBoardLinesColorPicked(color),
            ),
          ).toList(),
        )),
      ),
    ],
  );
}
