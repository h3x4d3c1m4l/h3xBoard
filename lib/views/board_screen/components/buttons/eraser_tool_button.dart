import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/drawing_tools.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/stroke_preset_row.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:h3xboard/views/components/flyouts/continuous_menu_flyout.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EraserToolButton extends StatelessWidget {

  const EraserToolButton({super.key, required this.viewModel, required this.controller});

  final BoardScreenViewModel viewModel;
  final BoardScreenController controller;

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) => ToolButton(
      icon: LucideIcons.eraser,
      title: context.localizations.eraserToolButton_erase,
      checked: viewModel.drawingTools.activeTool == .eraser,
      onPressed: () => controller.onSelectableToolButtonPressed(.eraser),
      dismissSignal: controller.drawStartSignal,
      flyoutBuilder: (context) => FlyoutContent(
        shape: continuousMenuShape(context),
        padding: .symmetric(horizontal: 16, vertical: 8),
        // The flyout is only as wide as its widest row: without this the divider,
        // which has no width of its own, stretches to the overlay's full width and
        // drags the flyout across the screen with it.
        child: Observer(builder: (_) => IntrinsicWidth(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            StrokePresetRow(
              presets: kEraserWidthPresets,
              value: viewModel.drawingTools.eraserWidth,
              onPresetSelected: controller.onEraserWidthChanged,
              isOutlined: true,
            ),
            const Divider(),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text(context.localizations.eraserToolButton_stroke),
                SizedBox(
                  height: 24,
                  child: Slider(min: 2, max: 64, value: viewModel.drawingTools.eraserWidth, onChanged: controller.onEraserWidthChanged),
                ),
                Container(
                  width: 64 / viewModel.boardPixelRatio,
                  height: 64 / viewModel.boardPixelRatio,
                  alignment: Alignment.center,
                  child: Container(
                    width: viewModel.drawingTools.eraserWidth / viewModel.boardPixelRatio,
                    height: viewModel.drawingTools.eraserWidth / viewModel.boardPixelRatio,
                    decoration: BoxDecoration(
                      border: BoxBorder.all(),
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ))),
      )),
    );
  }

}
