import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';

class DrawingColorButton extends StatefulWidget {

  final Color color;
  final bool isActive;
  final VoidCallback? onPressed;

  const DrawingColorButton({super.key, required this.color, required this.isActive, required this.onPressed});

  @override
  State<DrawingColorButton> createState() => _DrawingColorButtonState();

}

class _DrawingColorButtonState extends State<DrawingColorButton> with SingleTickerProviderStateMixin {

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
