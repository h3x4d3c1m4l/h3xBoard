import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/drawing_tools.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/stroke_preset_row.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

IconData _shapeIcon(ShapeKind shape) => switch (shape) {
      ShapeKind.line => LucideIcons.slash,
      ShapeKind.arrow => LucideIcons.moveUpRight,
      ShapeKind.rectangle => LucideIcons.square,
      ShapeKind.ellipse => LucideIcons.circle,
    };

String _shapeLabel(ShapeKind shape, AppLocalizations localizations) => switch (shape) {
      ShapeKind.line => localizations.markupToolButton_line,
      ShapeKind.arrow => localizations.markupToolButton_arrow,
      ShapeKind.rectangle => localizations.markupToolButton_rectangle,
      ShapeKind.ellipse => localizations.markupToolButton_ellipse,
    };

/// One toolbar button for the tools that mark up existing content — the
/// highlighter and the four shapes — as opposed to the pen, which writes. Keeps
/// the pen a single tap while five markup tools share one slot.
class MarkupToolButton extends StatelessWidget {

  const MarkupToolButton({super.key, required this.viewModel, required this.controller});

  final BoardScreenViewModel viewModel;
  final BoardScreenController controller;

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final tools = viewModel.drawingTools;
      final isHighlighter = tools.activeTool == SelectableEditTool.highlighter;
      // While the pen or eraser is active neither markup tool is, so the button
      // falls back to whichever one it will reactivate when pressed.
      final showsHighlighter = tools.activeTool != SelectableEditTool.shape &&
          (isHighlighter || tools.lastMarkupTool == MarkupTool.highlighter);

      return ToolButton(
        icon: showsHighlighter ? LucideIcons.highlighter : _shapeIcon(tools.activeShape),
        title: context.localizations.markupToolButton_markup,
        checked: isHighlighter || tools.activeTool == SelectableEditTool.shape,
        onPressed: controller.onMarkupButtonPressed,
        dismissSignal: controller.drawStartSignal,
        flyoutBuilder: (context) => FlyoutContent(
          padding: .symmetric(horizontal: 16, vertical: 8),
          // The flyout is only as wide as its widest row: without this the divider,
          // which has no width of its own, stretches to the overlay's full width
          // and drags the flyout across the screen with it.
          child: Observer(builder: (_) => IntrinsicWidth(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Tooltip(
                    message: context.localizations.markupToolButton_highlighter,
                    child: ToggleButton(
                      checked: isHighlighter,
                      onChanged: (_) => controller.onSelectableToolButtonPressed(.highlighter),
                      child: const Icon(LucideIcons.highlighter, size: 18),
                    ),
                  ),
                  for (final shape in ShapeKind.values)
                    Tooltip(
                      message: _shapeLabel(shape, context.localizations),
                      child: ToggleButton(
                        checked: tools.activeTool == SelectableEditTool.shape && tools.activeShape == shape,
                        onChanged: (_) => controller.onShapeKindSelected(shape),
                        child: Icon(_shapeIcon(shape), size: 18),
                      ),
                    ),
                ],
              ),
              // The presets and the stroke row below both drive whichever tool is
              // selected — the two keep separate widths, since a 24px marker and a
              // 4px rectangle are both right and one shared value would make one
              // of them wrong.
              StrokePresetRow(
                presets: isHighlighter ? kHighlighterWidthPresets : kShapeWidthPresets,
                value: isHighlighter ? tools.highlighterWidth : tools.shapeWidth,
                onPresetSelected: isHighlighter
                    ? controller.onHighlighterWidthChanged
                    : controller.onShapeWidthChanged,
                color: isHighlighter
                    ? tools.activeColor?.withValues(alpha: kHighlighterAlpha)
                    : tools.activeColor,
                isSquare: isHighlighter,
              ),
              const Divider(),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Text(context.localizations.markupToolButton_stroke),
                  SizedBox(
                    height: 24,
                    child: isHighlighter
                        ? Slider(min: 8, max: 64, value: tools.highlighterWidth, onChanged: controller.onHighlighterWidthChanged)
                        : Slider(min: 2, max: 64, value: tools.shapeWidth, onChanged: controller.onShapeWidthChanged),
                  ),
                  Container(
                    width: 64 / viewModel.boardPixelRatio,
                    height: 64 / viewModel.boardPixelRatio,
                    alignment: Alignment.center,
                    child: Container(
                      width: (isHighlighter ? tools.highlighterWidth : tools.shapeWidth) / viewModel.boardPixelRatio,
                      height: (isHighlighter ? tools.highlighterWidth : tools.shapeWidth) / viewModel.boardPixelRatio,
                      decoration: BoxDecoration(
                        // The marker preview is square and carries its own alpha,
                        // so it matches what lands on the canvas.
                        color: isHighlighter
                            ? tools.activeColor?.withValues(alpha: kHighlighterAlpha)
                            : tools.activeColor,
                        borderRadius: isHighlighter ? BorderRadius.circular(2) : null,
                        shape: isHighlighter ? BoxShape.rectangle : BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
              if (!isHighlighter && shapeSupportsFill(tools.activeShape))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    ToggleSwitch(
                      checked: tools.shapeFilled,
                      onChanged: controller.onShapeFilledChanged,
                    ),
                    Text(context.localizations.markupToolButton_filled),
                  ],
                ),
            ],
          ))),
        ),
      );
    });
  }

}
