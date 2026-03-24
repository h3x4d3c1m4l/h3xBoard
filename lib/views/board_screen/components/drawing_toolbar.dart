import 'package:fluent_ui/fluent_ui.dart';

class DrawingToolbar extends StatelessWidget {

  final Color activeColor;
  final ValueChanged<Color> onColorButtonPressed;

  const DrawingToolbar({super.key, required this.activeColor, required this.onColorButtonPressed});

  static final List<Color> _colors = [Colors.black, Colors.white, Colors.green, Colors.red, Colors.yellow, Colors.blue];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _colors.map((c) => _DrawingColorButton(
          color: c,
          isActive: c == activeColor,
          onPressed: () => onColorButtonPressed(c),
        ))
        .toList(),
    );
  }

}

class _DrawingColorButton extends StatelessWidget {

  final Color color;
  final bool isActive;
  final VoidCallback onPressed;

  const _DrawingColorButton({required this.color, required this.isActive, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: BoxBorder.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(blurRadius: 1)],
          ),
        ),
      ),
    );
  }

}
