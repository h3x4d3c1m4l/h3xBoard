import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PenToolButton extends StatelessWidget {

  const PenToolButton({super.key, required this.viewModel, required this.controller});

  final BoardScreenViewModel viewModel;
  final BoardScreenController controller;

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) => ToolButton(
      icon: LucideIcons.pen,
      title: context.localizations.penToolButton_draw,
      checked: viewModel.drawingTools.activeTool == .pen,
      onPressed: () => controller.onSelectableToolButtonPressed(.pen),
      flyoutBuilder: (context) => FlyoutContent(
        padding: .symmetric(horizontal: 16, vertical: 8),
        child: Observer(builder: (_) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Text(context.localizations.penToolButton_stroke),
            SizedBox(
              height: 24,
              child: Slider(min: 2, max: 64, value: viewModel.drawingTools.penWidth, onChanged: controller.onPenWidthSliderMoved),
            ),
            Container(
              width: 64 / viewModel.boardPixelRatio,
              height: 64 / viewModel.boardPixelRatio,
              alignment: Alignment.center,
              child: Container(
                width: viewModel.drawingTools.penWidth / viewModel.boardPixelRatio,
                height: viewModel.drawingTools.penWidth / viewModel.boardPixelRatio,
                decoration: BoxDecoration(
                  color: viewModel.drawingTools.activeColor,
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
