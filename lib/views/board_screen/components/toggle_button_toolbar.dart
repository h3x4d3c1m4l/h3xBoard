import 'package:fluent_ui/fluent_ui.dart';

enum _Side { left, middle, right }

class ToggleButtonToolbar extends StatelessWidget {

  final List<Widget> buttons;

  const ToggleButtonToolbar({super.key, required this.buttons})
    : assert(buttons.length >= 3, 'ToggleButtonToolbar needs at least 3 buttons');

  @override
  Widget build(BuildContext context) {
    FluentThemeData theme = FluentTheme.of(context);
    ToggleButtonThemeData leftToggleButtonTheme = _getToggleButtonTheme(context, theme, _Side.left);
    ToggleButtonThemeData middleToggleButtonTheme = _getToggleButtonTheme(context, theme, _Side.middle);
    ToggleButtonThemeData rightToggleButtonTheme = _getToggleButtonTheme(context, theme, _Side.right);
    ButtonThemeData leftButtonTheme = _getButtonTheme(context, theme, _Side.left);
    ButtonThemeData middleButtonTheme = _getButtonTheme(context, theme, _Side.middle);
    ButtonThemeData rightButtonTheme = _getButtonTheme(context, theme, _Side.right);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ToggleButtonTheme.merge(
          data: leftToggleButtonTheme,
          child: ButtonTheme.merge(data: leftButtonTheme, child: buttons.first),
        ),
        ...buttons.skip(1).take(buttons.length - 2).map((button) => ToggleButtonTheme.merge(
          data: middleToggleButtonTheme,
          child: ButtonTheme.merge(data: middleButtonTheme, child: button),
        )),
        ToggleButtonTheme.merge(data: rightToggleButtonTheme, child: ButtonTheme.merge(
          data: rightButtonTheme,
          child: buttons.last,
        )),
      ],
    );
  }

  ShapeBorder _getShapeBorder(ShapeBorder border, Set<WidgetState> widgetStates, _Side side) {
    if (border is RoundedRectangleBorder) {
      BorderRadius oldRadius = border.borderRadius as BorderRadius;
      return border.copyWith(borderRadius: oldRadius.copyWith(
        topLeft: side == _Side.left ? Radius.circular(16) : Radius.zero,
        bottomLeft: side == _Side.left ? Radius.circular(16) : Radius.zero,
        topRight: side == _Side.right ? Radius.circular(16) : Radius.zero,
        bottomRight: side == _Side.right ? Radius.circular(16) : Radius.zero,
      ));
    } else if (border is RoundedRectangleGradientBorder) {
      BorderRadius oldRadius = border.borderRadius as BorderRadius;

      return border.copyWith(
        gradient: border.gradient,
        borderRadius: oldRadius.copyWith(
          topLeft: side == _Side.left ? Radius.circular(16) : Radius.zero,
          bottomLeft: side == _Side.left ? Radius.circular(16) : Radius.zero,
          topRight: side == _Side.right ? Radius.circular(16) : Radius.zero,
          bottomRight: side == _Side.right ? Radius.circular(16) : Radius.zero,
        ),
        width: border.width,
        strokeAlign: border.strokeAlign,
      );
    } else {
      throw Exception('Unsupported');
    }
  }

  ToggleButtonThemeData _getToggleButtonTheme(BuildContext context, FluentThemeData theme, _Side side) {
    return ToggleButtonThemeData(
      checkedButtonStyle: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) => FilledButton.foregroundColor(theme, states)),
        backgroundColor: WidgetStateProperty.resolveWith((states) => FilledButton.backgroundColor(theme, states)),
        shape: WidgetStateProperty.resolveWith(
          (states) => _getShapeBorder(FilledButton.shapeBorder(theme, states), states, side),
        ),
      ),
      uncheckedButtonStyle: _getButtonTheme(context, theme, side).defaultButtonStyle,
    );
  }

  ButtonThemeData _getButtonTheme(BuildContext context, FluentThemeData theme, _Side side) {
    return ButtonThemeData(
      defaultButtonStyle: ButtonStyle(
        shape: WidgetStateProperty.resolveWith(
          (states) => _getShapeBorder(ButtonThemeData.shapeBorder(context, states), states, side),
        ),
      ),
    );
  }

}
