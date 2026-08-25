import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';

/// A [ContinuousTextBox] that registers itself with the surrounding
/// [FormBuilder] under [name] — so the form owns the value, the validator and
/// the error, and the screen only has to say what the field is called.
///
/// The package's own [FormBuilderTextField] cannot be used for this: it is built
/// on Material's `TextField` and `InputDecoration`, and this app is fluent
/// throughout. [FormBuilderField] is the part that is *not* Material — it is a
/// plain [FormField] subclass over `package:flutter/widgets.dart` — so wrapping
/// it around our own box is the supported way to bring a foreign control into a
/// form. Nothing Material enters the tree.
///
/// Two things have to be bridged, and both are load-bearing.
///
/// **The [TextEditingController]**: a [FormBuilderField] keeps the value, a
/// fluent [TextBox] keeps a controller, and both have to agree without echoing
/// each other. Typing goes one way (`onChanged` → [FormFieldState.didChange])
/// and everything the *form* does to the value — `reset()`, `patchValue()` —
/// comes back the other, applied only when the two actually differ so the round
/// trip stops after one step.
///
/// **The [FocusNode]**, which is not optional here. `FormBuilderFieldState`
/// focuses its own `effectiveFocusNode` whenever it validates an invalid field
/// and finds that *no* field in the form is focused — the "jump to the first
/// problem" behaviour. `FormState` re-validates every field on every build once
/// the user has interacted with the form, so that check runs constantly. If the
/// node it watches is not the one the text box holds, the two disagree: the
/// box has the focus, the form concludes nothing does, and it takes the focus
/// away — on a tablet that is the keyboard opening and shutting again on every
/// tap. So the same node is handed to both, and the field's own machinery
/// (`isTouched`, focus-on-invalid) starts working as designed as a bonus.
class FormBuilderContinuousTextBox extends StatefulWidget {

  /// The field's name within the form — the key its value appears under in
  /// [FormBuilderState.value].
  final String name;

  final String? placeholder;

  /// The rule the form checks this field against, or `null` for a field that is
  /// always acceptable.
  final FormFieldValidator<String>? validator;

  /// Massages the value on its way into [FormBuilderState.value], without
  /// touching what the field shows. The email field trims with this.
  final ValueTransformer<String?>? valueTransformer;

  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const FormBuilderContinuousTextBox({
    super.key,
    required this.name,
    this.placeholder,
    this.validator,
    this.valueTransformer,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<FormBuilderContinuousTextBox> createState() => _FormBuilderContinuousTextBoxState();

}

class _FormBuilderContinuousTextBoxState extends State<FormBuilderContinuousTextBox> {

  /// Owned here rather than by either side, so the form field and the text box
  /// are demonstrably given the same one. [FormBuilderField] disposes the node
  /// it makes itself, but never one it was handed — hence the dispose below.
  final _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<String>(
      name: widget.name,
      focusNode: _focusNode,
      validator: widget.validator,
      valueTransformer: widget.valueTransformer,
      enabled: widget.enabled,
      builder: (field) => _ControlledTextBox(
        field: field,
        focusNode: _focusNode,
        placeholder: widget.placeholder,
        enabled: widget.enabled,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

}

/// The box itself, holding the [TextEditingController] the field does not have.
class _ControlledTextBox extends StatefulWidget {

  final FormFieldState<String> field;
  final FocusNode focusNode;
  final String? placeholder;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _ControlledTextBox({
    required this.field,
    required this.focusNode,
    required this.placeholder,
    required this.enabled,
    required this.obscureText,
    required this.keyboardType,
    required this.autofillHints,
    required this.textInputAction,
    required this.onSubmitted,
  });

  @override
  State<_ControlledTextBox> createState() => _ControlledTextBoxState();

}

class _ControlledTextBoxState extends State<_ControlledTextBox> {

  late final TextEditingController _controller = TextEditingController(text: widget.field.value ?? '');

  @override
  void didUpdateWidget(_ControlledTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.field.value ?? '';
    // Only when they differ: a keystroke reaches the field through didChange and
    // comes straight back here as a rebuild, and re-assigning the same text
    // would collapse the caret to the end mid-word.
    if (value != _controller.text) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContinuousTextBox(
      controller: _controller,
      focusNode: widget.focusNode,
      placeholder: widget.placeholder,
      errorText: widget.field.errorText,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onChanged: widget.field.didChange,
      onSubmitted: widget.onSubmitted,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

}
