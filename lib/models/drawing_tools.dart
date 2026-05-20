import 'package:fluent_ui/fluent_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'drawing_tools.freezed.dart';

enum SelectableEditTool { pointer, pen, eraser }

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
  }) = _DrawingTools;

}
