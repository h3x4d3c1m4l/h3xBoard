import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BoardSettingsButton extends StatefulWidget {
  const BoardSettingsButton({super.key, required this.viewModel, required this.controller});

  final BoardScreenViewModel viewModel;
  final BoardScreenController controller;

  @override
  State<BoardSettingsButton> createState() => _BoardSettingsButtonState();
}

class _BoardSettingsButtonState extends State<BoardSettingsButton> {
  final FlyoutController _menuController = FlyoutController();
  static const List<Color> _regularBoardColors = [Colors.black, Colors.white];
  static const List<Color> _chalkboardColors = [Color(0xFF1F3A2E), Color(0xFF2B2F3A)];

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => ToolButton(
        icon: LucideIcons.settings,
        title: 'Settings',
        onPressed: () {},
        flyoutBuilder: (context) => Observer(
          builder: (context) => MenuFlyout(
            items: [
              MenuFlyoutSubItem(
                leading: Icon(LucideIcons.paintBucket),
                text: const Text('Board color:'),
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
                              children: _regularBoardColors.map((color) => _BackgroundColorButton(
                                color: color,
                                isActive: widget.viewModel.boardColor == color,
                                onPressed: () {
                                  Flyout.of(context).close();
                                  widget.controller.onBoardBackgroundColorPicked(color, false);
                                },
                              )).toList(),
                            ),
                            Row(
                              spacing: 8,
                              mainAxisSize: MainAxisSize.min,
                              children: _chalkboardColors.map((color) => _BackgroundColorButton(
                                color: color,
                                isActive: widget.viewModel.boardColor == color,
                                onPressed: () {
                                  Flyout.of(context).close();
                                  widget.controller.onBoardBackgroundColorPicked(color, true);
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }
}

class _BackgroundColorButton extends StatelessWidget {
  final Color color;
  final bool isActive;
  final VoidCallback onPressed;

  const _BackgroundColorButton({required this.color, required this.isActive, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Button(
      key: ValueKey('$color $isActive'),
      onPressed: onPressed,
      style: ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsetsDirectional.all(4))),
      autofocus: isActive,
      child: Container(width: 32, height: 32, color: color),
    );
  }
}
