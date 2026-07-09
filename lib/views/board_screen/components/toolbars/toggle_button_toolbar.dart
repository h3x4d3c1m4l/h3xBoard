import 'package:fluent_ui/fluent_ui.dart';

class ToggleButtonToolbar extends StatelessWidget {

  final List<Widget> buttons;

  /// Lay the buttons out along this axis, matching the parent toolbar.
  final Axis direction;

  /// Concentric with the parent toolbar: its radius minus its inner padding.
  final double borderRadius;

  const ToggleButtonToolbar({super.key, required this.buttons, this.direction = Axis.horizontal, this.borderRadius = 28})
    : assert(buttons.length > 0, 'ToggleButtonToolbar needs at least 1 button');

  @override
  Widget build(BuildContext context) {
    FluentThemeData theme = FluentTheme.of(context);
    ToggleButtonThemeData toggleButtonTheme = _getToggleButtonTheme(theme);
    ButtonThemeData buttonTheme = _getButtonTheme();

    return Flex(
      direction: direction,
      mainAxisSize: .min,
      spacing: 6,
      children: buttons
          .map((button) => ToggleButtonTheme.merge(
                data: toggleButtonTheme,
                child: ButtonTheme.merge(data: buttonTheme, child: button),
              ))
          .toList(),
    );
  }

  ShapeBorder _getShapeBorder() {
    return ContinuousRectangleBorder(borderRadius: BorderRadius.circular(borderRadius));
  }

  ToggleButtonThemeData _getToggleButtonTheme(FluentThemeData theme) {
    return ToggleButtonThemeData(
      checkedButtonStyle: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) => FilledButton.foregroundColor(theme, states)),
        backgroundColor: WidgetStateProperty.resolveWith((states) => FilledButton.backgroundColor(theme, states)),
        shape: WidgetStateProperty.resolveWith(
          (states) => _getShapeBorder(),
        ),
      ),
      uncheckedButtonStyle: _getButtonTheme().defaultButtonStyle,
    );
  }

  ButtonThemeData _getButtonTheme() {
    return ButtonThemeData(
      defaultButtonStyle: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.resolveWith(
          (states) => _getShapeBorder(),
        ),
      ),
    );
  }

}
