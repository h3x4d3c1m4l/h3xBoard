import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/board_screen/components/buttons/custom_color_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/drawing_color_button.dart';

class DrawingToolbar extends StatelessWidget {

  final Color? activeColor;
  final ValueChanged<Color>? onColorButtonPressed;

  /// The bar's layout axis. Vertical (default) when docked left/right; horizontal
  /// when docked top/bottom.
  final Axis direction;

  const DrawingToolbar({
    super.key,
    required this.activeColor,
    required this.onColorButtonPressed,
    this.direction = Axis.vertical,
  });

  static final List<Color> _colors = [Colors.black, Colors.white, Colors.green, Colors.red, Colors.yellow, Colors.blue];

  @override
  Widget build(BuildContext context) {
    final children = [
      ..._colors.map((c) => DrawingColorButton(
        color: c,
        isActive: c == activeColor,
        onPressed: onColorButtonPressed != null ? () => onColorButtonPressed!(c) : null,
      )),
      Divider(
        direction: direction == Axis.vertical ? Axis.horizontal : Axis.vertical,
        size: 24,
      ),
      CustomColorButton(
        pickedColorIsActive: activeColor != null && !_colors.contains(activeColor),
        onColorPicked: onColorButtonPressed,
      ),
    ];

    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: children,
    );
  }

}
