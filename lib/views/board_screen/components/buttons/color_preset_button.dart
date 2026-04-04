import 'package:fluent_ui/fluent_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ColorPresetButton extends StatelessWidget {

  final Color color;
  final bool isActive;
  final VoidCallback onPressed;
  final bool isChalkboard;

  const ColorPresetButton({super.key, required this.color, required this.isActive, required this.onPressed, this.isChalkboard = false});

  @override
  Widget build(BuildContext context) {
    return Button(
      key: ValueKey('$color $isActive'),
      onPressed: onPressed,
      style: ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsetsDirectional.all(4))),
      autofocus: isActive,
      child: Container(
        width: 32,
        height: 32,
        color: color,
        child: isChalkboard ? Icon(LucideIcons.pen, color: Colors.white) : null,
      ),
    );
  }

}
