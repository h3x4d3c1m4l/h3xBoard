import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/laser_pointer.dart';

/// One laser colour, drawn as a miniature of the dot it produces — coloured
/// bloom around a white-hot core — so the swatch previews the thing rather than
/// just naming it.
class LaserColorButton extends StatelessWidget {

  final LaserColor laserColor;
  final bool isActive;
  final VoidCallback onPressed;

  const LaserColorButton({
    super.key,
    required this.laserColor,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = laserColor.color;
    return Tooltip(
      message: _label(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? theme.accentColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8)],
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(Colors.white, color, 0.12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label(BuildContext context) => switch (laserColor) {
        LaserColor.red => context.localizations.laserColor_red,
        LaserColor.green => context.localizations.laserColor_green,
        LaserColor.blue => context.localizations.laserColor_blue,
        LaserColor.magenta => context.localizations.laserColor_magenta,
      };

}
