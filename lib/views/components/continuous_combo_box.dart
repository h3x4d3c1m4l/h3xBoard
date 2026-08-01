import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/theme/app_theme.dart';

/// A [ComboBox] wearing the app's squircle, so dropdowns match the text fields
/// and buttons around them.
///
/// Fluent builds a combo box's closed state out of a plain [Button] and offers
/// no combo-box theme slot, so the shape can only be handed to it through an
/// ambient [ButtonTheme] — which is what this does, with
/// [AppButtonStyles.comboBox]. That style is the neutral outline at the smaller
/// [kShortControlCornerRadius], since fluent pins the closed state to a fixed
/// 32px height.
///
/// Sibling of [ContinuousTextBox], which solves the same problem for [TextBox].
class ContinuousComboBox<T> extends StatelessWidget {

  /// The currently selected value, or `null` to show [placeholder].
  final T? value;

  final List<ComboBoxItem<T>> items;

  /// Shown while [value] is null. A null [onChanged] disables the combo box.
  final Widget? placeholder;

  final ValueChanged<T?>? onChanged;

  const ContinuousComboBox({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return ButtonTheme.merge(
      data: ButtonThemeData(defaultButtonStyle: context.appTheme.buttons.comboBox),
      child: ComboBox<T>(
        value: value,
        items: items,
        placeholder: placeholder,
        onChanged: onChanged,
      ),
    );
  }

}
