import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/theme/shape_metrics.dart';

/// A [TextBox] wrapped in a [ContinuousRectangleBorder], so text fields match
/// the app's squircle buttons and dialogs.
///
/// fluent's [TextBox] is hardwired to a `BoxDecoration` (circular corners only)
/// and exposes no global theme, so we suppress its own border/focus-underline
/// and draw the continuous border + fill ourselves. The border turns the accent
/// color while focused, mirroring fluent's default focus affordance.
class ContinuousTextBox extends StatefulWidget {

  /// Creates a text field with a continuous-rectangle border.
  const ContinuousTextBox({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
    this.style,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController? controller;

  final FocusNode? focusNode;

  final String? placeholder;

  final bool enabled;

  final bool obscureText;

  final TextInputType? keyboardType;

  final Iterable<String>? autofillHints;

  final void Function(String)? onSubmitted;

  final TextStyle? style;

  final int? minLines;

  final int? maxLines;

  @override
  State<ContinuousTextBox> createState() => _ContinuousTextBoxState();

}

class _ContinuousTextBoxState extends State<ContinuousTextBox> {

  FocusNode? _internalNode;

  FocusNode get _focusNode => widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void initState() {

    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(ContinuousTextBox oldWidget) {

    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      _focusNode.addListener(_onFocusChanged);
    }
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {

    (widget.focusNode ?? _internalNode)?.removeListener(_onFocusChanged);
    _internalNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final theme = FluentTheme.of(context);
    final res = theme.resources;
    final focused = _focusNode.hasFocus;

    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(kControlCornerRadius),
      side: BorderSide(
        color: focused ? theme.accentColor : res.controlStrokeColorDefault,
        width: focused ? 2 : 1,
      ),
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: widget.enabled ? res.controlFillColorDefault : res.controlFillColorDisabled,
        shape: shape,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: shape,
          textDirection: Directionality.maybeOf(context),
        ),
        child: TextBox(
          controller: widget.controller,
          focusNode: _focusNode,
          placeholder: widget.placeholder,
          enabled: widget.enabled,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          onSubmitted: widget.onSubmitted,
          style: widget.style,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          padding: kControlPadding,
          // Make the inner field transparent and borderless; the wrapper draws
          // the fill + continuous border. Border() (all sides none) overrides
          // fluent's default box border and focus underline.
          decoration: WidgetStatePropertyAll(
            BoxDecoration(border: Border(), color: Colors.transparent),
          ),
          foregroundDecoration: WidgetStatePropertyAll(
            BoxDecoration(border: Border()),
          ),
        ),
      ),
    );
  }

}
