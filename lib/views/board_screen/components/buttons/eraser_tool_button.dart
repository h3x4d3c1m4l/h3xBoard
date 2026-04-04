import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EraserToolButton extends StatelessWidget {

  const EraserToolButton({super.key, required this.viewModel, required this.controller});

  final BoardScreenViewModel viewModel;
  final BoardScreenController controller;

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) => ToolButton(
      icon: LucideIcons.eraser,
      title: 'Erase',
      checked: viewModel.activeTool == .eraser,
      onPressed: () => controller.onSelectableToolButtonPressed(.eraser),
      flyoutBuilder: (context) => FlyoutContent(
        child: Observer(builder: (_) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text('Stroke:'),
            SizedBox(
              height: 24,
              child: Slider(min: 2, max: 64, value: viewModel.eraserWidth, onChanged: controller.onEraserWidthSliderMoved),
            ),
            Container(
              width: 64 / viewModel.boardPixelRatio,
              height: 64 / viewModel.boardPixelRatio,
              alignment: Alignment.center,
              child: Container(
                width: viewModel.eraserWidth / viewModel.boardPixelRatio,
                height: viewModel.eraserWidth / viewModel.boardPixelRatio,
                decoration: BoxDecoration(
                  border: BoxBorder.all(),
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                ),
              ),
            ),
          ],
        )),
      )),
    );
  }

}
