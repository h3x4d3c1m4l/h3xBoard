import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/drawing_tools.dart';

DrawingTools _tools({
  required SelectableEditTool activeTool,
  Color? activeColor = const Color(0xFF00FF00),
  ShapeKind activeShape = ShapeKind.rectangle,
  bool shapeFilled = false,
}) =>
    DrawingTools(
      activeColor: activeColor,
      lastActiveColor: const Color(0xFF00FF00),
      activeTool: activeTool,
      penWidth: 2,
      eraserWidth: 8,
      activeShape: activeShape,
      shapeFilled: shapeFilled,
    );

void main() {
  group('paintStyleFor', () {
    test('the pointer draws nothing', () {
      expect(paintStyleFor(_tools(activeTool: SelectableEditTool.pointer)), isNull);
    });

    // The eraser reuses the shared paint and only overrides its blend mode, so
    // both of these would otherwise be inherited from the previous tool:
    // a fill style turns its open path into a filled blob (erasing everything
    // the drag encloses), and a translucent colour makes BlendMode.clear erase
    // only partway. Neither can be expressed through the eraser's own UI, so
    // these assertions are the only thing holding them.
    test('the eraser always strokes, whatever the shape tool was set to', () {
      final style = paintStyleFor(_tools(
        activeTool: SelectableEditTool.eraser,
        activeShape: ShapeKind.rectangle,
        shapeFilled: true,
      ));

      expect(style!.style, PaintingStyle.stroke);
    });

    test('the eraser is fully opaque, whatever the highlighter was set to', () {
      final style = paintStyleFor(_tools(activeTool: SelectableEditTool.eraser));

      expect(style!.color?.a, 1.0);
    });

    test('the highlighter is translucent', () {
      final style = paintStyleFor(_tools(activeTool: SelectableEditTool.highlighter));

      expect(style!.color?.a, closeTo(kHighlighterAlpha, 0.01));
      expect(style.style, PaintingStyle.stroke);
    });

    test('only a fillable shape with the flag set actually fills', () {
      PaintingStyle styleOf(ShapeKind shape, {required bool filled}) => paintStyleFor(_tools(
            activeTool: SelectableEditTool.shape,
            activeShape: shape,
            shapeFilled: filled,
          ))!.style;

      expect(styleOf(ShapeKind.rectangle, filled: true), PaintingStyle.fill);
      expect(styleOf(ShapeKind.ellipse, filled: true), PaintingStyle.fill);
      expect(styleOf(ShapeKind.rectangle, filled: false), PaintingStyle.stroke);
      // The flag is shared across shapes, so it stays set when the user moves to
      // a line or arrow — neither of which can honour it.
      expect(styleOf(ShapeKind.line, filled: true), PaintingStyle.stroke);
      expect(styleOf(ShapeKind.arrow, filled: true), PaintingStyle.stroke);
    });

    test('each tool draws at its own width', () {
      double widthOf(SelectableEditTool tool) => paintStyleFor(_tools(activeTool: tool))!.strokeWidth;

      expect(widthOf(SelectableEditTool.pen), 2);
      expect(widthOf(SelectableEditTool.eraser), 8);
      expect(widthOf(SelectableEditTool.highlighter), 24);
      expect(widthOf(SelectableEditTool.shape), 4);
    });
  });

  group('stroke width presets', () {
    // (presets, slider min, slider max, the tool's default width). The ranges
    // repeat the literals the flyout sliders are built with.
    final tools = {
      'pen': (kPenWidthPresets, 2.0, 64.0, 2.0),
      'highlighter': (kHighlighterWidthPresets, 8.0, 64.0, 24.0),
      'shape': (kShapeWidthPresets, 2.0, 64.0, 4.0),
      'eraser': (kEraserWidthPresets, 2.0, 64.0, 8.0),
    };

    for (final MapEntry(key: name, value: spec) in tools.entries) {
      final (presets, min, max, defaultWidth) = spec;

      test('$name offers five presets, ordered small to large', () {
        expect(presets, hasLength(5));
        expect(presets, orderedEquals(presets.toList()..sort()));
        expect(presets.toSet(), hasLength(5));
      });

      // A preset outside its slider's range could be picked but never dragged
      // back to, stranding the tool at a width its own slider cannot express.
      test('$name presets stay within its slider range', () {
        for (final preset in presets) {
          expect(preset, inInclusiveRange(min, max), reason: '$preset is off the $name slider');
        }
      });

      // Otherwise the row opens with nothing selected, reading as "no size set".
      test('$name starts on one of its presets', () {
        expect(presets, contains(defaultWidth));
      });
    }
  });
}
