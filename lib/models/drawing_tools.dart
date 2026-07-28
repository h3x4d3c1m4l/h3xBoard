import 'package:fluent_ui/fluent_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'drawing_tools.freezed.dart';

enum SelectableEditTool { pointer, pen, highlighter, shape, eraser }

enum ShapeKind { line, arrow, rectangle, ellipse }

// The two tools behind the single markup toolbar button.
enum MarkupTool { highlighter, shape }

const double kHighlighterAlpha = 0.35;

bool toolUsesActiveColor(SelectableEditTool tool) =>
    tool == SelectableEditTool.pen ||
    tool == SelectableEditTool.highlighter ||
    tool == SelectableEditTool.shape;

bool toolProducesStrokes(SelectableEditTool tool) => tool != SelectableEditTool.pointer;

bool shapeSupportsFill(ShapeKind shape) =>
    shape == ShapeKind.rectangle || shape == ShapeKind.ellipse;

/// The paint properties a tool draws with.
typedef ToolPaintStyle = ({Color? color, double strokeWidth, PaintingStyle style});

/// The style [tools]' active tool should draw with, or null for the pointer,
/// which draws nothing.
///
/// Every tool states all three properties. `DrawingController.setStyle` merges
/// into one shared config (`x ?? this.x`), so a property left unset silently
/// inherits the previous tool's value — and two of those inheritances break the
/// eraser, which reuses the shared paint and only overrides its blend mode:
/// [PaintingStyle.fill] from a filled shape turns its open path into a filled
/// blob, and a translucent highlighter colour leaves `BlendMode.clear` erasing
/// only partway.
ToolPaintStyle? paintStyleFor(DrawingTools tools) => switch (tools.activeTool) {
      SelectableEditTool.pointer => null,
      SelectableEditTool.pen => (
          color: tools.activeColor,
          strokeWidth: tools.penWidth,
          style: PaintingStyle.stroke,
        ),
      SelectableEditTool.highlighter => (
          color: tools.activeColor?.withValues(alpha: kHighlighterAlpha),
          strokeWidth: tools.highlighterWidth,
          style: PaintingStyle.stroke,
        ),
      SelectableEditTool.shape => (
          color: tools.activeColor,
          strokeWidth: tools.shapeWidth,
          style: tools.shapeFilled && shapeSupportsFill(tools.activeShape)
              ? PaintingStyle.fill
              : PaintingStyle.stroke,
        ),
      SelectableEditTool.eraser => (
          color: const Color(0xFF000000),
          strokeWidth: tools.eraserWidth,
          style: PaintingStyle.stroke,
        ),
    };

@freezed
abstract class DrawingTools with _$DrawingTools {

  const DrawingTools._();

  const factory DrawingTools({
    required Color? activeColor,
    required Color lastActiveColor,
    required SelectableEditTool activeTool,
    @Default(SelectableEditTool.pen) SelectableEditTool lastActiveTool,
    required double penWidth,
    required double eraserWidth,
    @Default(24.0) double highlighterWidth,
    @Default(4.0) double shapeWidth,
    @Default(ShapeKind.line) ShapeKind activeShape,
    @Default(false) bool shapeFilled,
    @Default(MarkupTool.highlighter) MarkupTool lastMarkupTool,
  }) = _DrawingTools;

}
