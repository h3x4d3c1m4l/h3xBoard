import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/theme/app_theme.dart';

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
    AppButtonStyles buttonStyles = context.appTheme.buttons;
    ToggleButtonThemeData toggleButtonTheme = _getToggleButtonTheme(buttonStyles);
    ButtonThemeData buttonTheme = _getButtonTheme(buttonStyles);

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

  /// The toolbar item styles carry everything but the shape — the radius is the
  /// one thing only this widget knows, since it is concentric with the bar that
  /// holds it.
  WidgetStateProperty<ShapeBorder?> get _shape => WidgetStatePropertyAll(
    ContinuousRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
  );

  ToggleButtonThemeData _getToggleButtonTheme(AppButtonStyles buttonStyles) {
    return ToggleButtonThemeData(
      checkedButtonStyle: buttonStyles.toolbarItemChecked.copyWith(shape: _shape),
      uncheckedButtonStyle: _getButtonTheme(buttonStyles).defaultButtonStyle,
    );
  }

  ButtonThemeData _getButtonTheme(AppButtonStyles buttonStyles) {
    return ButtonThemeData(
      defaultButtonStyle: buttonStyles.toolbarItem.copyWith(shape: _shape),
    );
  }

}
