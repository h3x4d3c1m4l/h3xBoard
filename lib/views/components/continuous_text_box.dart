import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A [TextBox] wrapped in a [ContinuousRectangleBorder], so text fields match
/// the app's squircle buttons and dialogs.
///
/// fluent's [TextBox] is hardwired to a `BoxDecoration` (circular corners only)
/// and exposes no global theme, so we suppress its own border/focus-underline
/// and draw the continuous border + fill ourselves. The border turns the accent
/// color while focused, mirroring fluent's default focus affordance.
class ContinuousTextBox extends StatefulWidget {

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final Widget? prefix;
  final bool enabled;
  final bool autofocus;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final void Function(PointerDownEvent)? onTapOutside;
  final TextStyle? style;
  final int? minLines;
  final int? maxLines;
  final TextInputAction? textInputAction;

  /// The selection toolbar (copy/paste/…) to show. Defaults to Flutter's
  /// adaptive toolbar, which renders a platform-native menu — notably one
  /// *without* the desktop keyboard shortcut labels ("Ctrl+C", …) that fluent's
  /// own [TextBox.defaultContextMenuBuilder] always draws and which are
  /// meaningless on touch devices.
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  const ContinuousTextBox({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.prefix,
    this.enabled = true,
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.onTapOutside,
    this.style,
    this.minLines,
    this.maxLines = 1,
    this.textInputAction,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
  });

  static Widget _defaultContextMenuBuilder(BuildContext context, EditableTextState editableTextState) {
    return AdaptiveTextSelectionToolbar.editableText(editableTextState: editableTextState);
  }

  @override
  State<ContinuousTextBox> createState() => _ContinuousTextBoxState();

}

class _ContinuousTextBoxState extends State<ContinuousTextBox> {

  FocusNode? _internalNode;
  FocusNode get _focusNode => widget.focusNode ?? (_internalNode ??= FocusNode());
  late bool _obscured = widget.obscureText;

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
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  void _onFocusChanged() => setState(() {});

  Widget _buildVisibilityToggle(BuildContext context) {
    final label = _obscured
        ? context.localizations.continuousTextBox_showPassword
        : context.localizations.continuousTextBox_hidePassword;

    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(_obscured ? LucideIcons.eye : LucideIcons.eyeOff),
        onPressed: widget.enabled ? () => setState(() => _obscured = !_obscured) : null,
      ),
    );
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
          prefix: widget.prefix,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _obscured,
          suffix: widget.obscureText ? _buildVisibilityToggle(context) : null,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          onTapOutside: widget.onTapOutside,
          style: widget.style,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          padding: kControlPadding,
          textInputAction: widget.textInputAction,
          contextMenuBuilder: widget.contextMenuBuilder,
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

  @override
  void dispose() {
    (widget.focusNode ?? _internalNode)?.removeListener(_onFocusChanged);
    _internalNode?.dispose();
    super.dispose();
  }

}
