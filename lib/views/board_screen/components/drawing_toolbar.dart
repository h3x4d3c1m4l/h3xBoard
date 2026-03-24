import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';

class DrawingToolbar extends StatelessWidget {

  final Color? activeColor;
  final ValueChanged<Color> onColorButtonPressed;

  const DrawingToolbar({super.key, required this.activeColor, required this.onColorButtonPressed});

  static final List<Color> _colors = [Colors.black, Colors.white, Colors.green, Colors.red, Colors.yellow, Colors.blue];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: _colors.map((c) => _DrawingColorButton(
        color: c,
        isActive: c == activeColor,
        onPressed: () => onColorButtonPressed(c),
      )).toList(),
    );
  }

}

class _DrawingColorButton extends StatefulWidget {

  final Color color;
  final bool isActive;
  final VoidCallback onPressed;

  const _DrawingColorButton({required this.color, required this.isActive, required this.onPressed});

  @override
  State<_DrawingColorButton> createState() => _DrawingColorButtonState();

}

class _DrawingColorButtonState extends State<_DrawingColorButton> with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.isActive ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOutCirc,
      builder: (context, t, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Padding(
            padding: EdgeInsets.all(lerpDouble(8, 2, t)!),
            child: Container(
              width: lerpDouble(32, 44, t),
              height: lerpDouble(32, 44, t),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  const BoxShadow(blurRadius: 2),
                  BoxShadow(
                    blurRadius: lerpDouble(0, 16, t)!,
                    color: widget.color.withValues(alpha: t),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

}
