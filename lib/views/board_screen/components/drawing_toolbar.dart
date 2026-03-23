import 'package:fluent_ui/fluent_ui.dart';

class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      children: [
        DrawingColorButton(color: Colors.black, onPressed: () {}),
        DrawingColorButton(color: Colors.white, onPressed: () {}),
        DrawingColorButton(color: Colors.green, onPressed: () {}),
        DrawingColorButton(color: Colors.red, onPressed: () {}),
        DrawingColorButton(color: Colors.yellow, onPressed: () {}),
        DrawingColorButton(color: Colors.blue, onPressed: () {}),
      ],
    );
  }
}

class DrawingColorButton extends StatelessWidget {
  final Color color;
  final VoidCallback onPressed;

  const DrawingColorButton({super.key, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
    );
  }
}
