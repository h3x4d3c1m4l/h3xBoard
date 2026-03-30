import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';

class CustomColorButton extends StatefulWidget {

  final bool pickedColorIsActive;
  final ValueChanged<Color>? onColorPicked;

  const CustomColorButton({super.key, required this.pickedColorIsActive, required this.onColorPicked});

  @override
  State<CustomColorButton> createState() => _CustomColorButtonState();

}

class _CustomColorButtonState extends State<CustomColorButton> with SingleTickerProviderStateMixin {

  late final AnimationController _controller;
  late final FlyoutController _colorSelectionController = FlyoutController();

  Color _lastPicked = Colors.teal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: _colorSelectionController,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.pickedColorIsActive ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCirc,
        builder: (context, t, _) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onColorPicked != null ? _onPressed : null,
            child: Padding(
              padding: EdgeInsets.all(lerpDouble(8, 2, t)!),
              child: Container(
                width: lerpDouble(32, 44, t),
                height: lerpDouble(32, 44, t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Color(0xFFDD0000),
                      Color(0xFFFF7F00),
                      Color(0xFFDDDD00),
                      Color(0xFF00DD00),
                      Color(0xFF0000FF),
                      Color(0xFF4B0082),
                      Color(0xFF8B00FF),
                      Color(0xFFDD0000),
                    ],
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    const BoxShadow(blurRadius: 2),
                    BoxShadow(
                      blurRadius: lerpDouble(0, 16, t)!,
                      color: _lastPicked.withValues(alpha: t),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onPressed() {
    _colorSelectionController.showFlyout(
      builder: (context) => FlyoutContent(child: ColorPicker(
        orientation: Axis.horizontal,
        isAlphaEnabled: false,
        isColorChannelTextInputVisible: false,
        isHexInputVisible: false,
        color: _lastPicked,
        onChanged: (color) {
          setState(() => _lastPicked = color);
          widget.onColorPicked!(color);
        },
      )),
      placementMode: FlyoutPlacementMode.rightCenter,
      additionalOffset: 16,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _colorSelectionController.dispose();
    super.dispose();
  }

}
