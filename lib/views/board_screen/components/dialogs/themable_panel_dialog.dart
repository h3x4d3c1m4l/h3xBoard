import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart' show DecorationClipper;

/// A plain, content-focused dialog for larger panels (Add Widget, Board
/// Settings): a calm white surface with a defined gray border and no animated
/// background pattern — the opposite of the accent/status-tinted, pattern-backed
/// [ThemableContentDialog] used for confirmations.
///
/// Its footer is split into two groups: [leftActions] (e.g. "Reset to default",
/// "Copy from…") are aligned to the start and [rightActions] (e.g. Cancel, OK)
/// to the end. The footer is omitted entirely when both are empty.
class ThemablePanelDialog extends StatelessWidget {

  /// The slate-gray border around the white surface.
  static const Color _borderColor = Color(0xFF6B7280);

  const ThemablePanelDialog({
    super.key,
    required this.content,
    this.leftActions = const [],
    this.rightActions = const [],
    this.actionsBackgroundColor,
    this.constraints = const BoxConstraints(maxWidth: 368, maxHeight: 756),
  });

  /// The body of the dialog. Provides its own padding (this dialog only adds the
  /// ambient [ContentDialogThemeData.padding] around it, matching the confirmation dialog).
  final Widget content;

  /// Footer actions aligned to the start (left).
  final List<Widget> leftActions;

  /// Footer actions aligned to the end (right).
  final List<Widget> rightActions;

  /// The fill behind the footer. Defaults to [FluentThemeData.micaBackgroundColor]
  /// — a soft gray actions bar, like fluent's own dialogs.
  final Color? actionsBackgroundColor;

  /// The constraints of the dialog.
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {

    assert(debugCheckHasFluentTheme(context), 'A FluentTheme ancestor is required.');
    final theme = FluentTheme.of(context);
    final style = ContentDialogTheme.of(context);
    final decoration = _plainDecoration(style.decoration);
    final hasActions = leftActions.isNotEmpty || rightActions.isNotEmpty;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Padding(
            padding: style.padding ?? EdgeInsetsDirectional.zero,
            child: content,
          ),
        ),
        if (hasActions)
          Container(
            // Match fluent's own dialogs: a soft gray actions bar against the
            // (white) surface.
            color: actionsBackgroundColor ?? theme.micaBackgroundColor,
            padding: style.actionsPadding,
            child: _buildActions(style.actionsSpacing ?? 8),
          ),
      ],
    );

    return Align(
      alignment: AlignmentDirectional.center,
      child: Container(
        constraints: constraints,
        decoration: decoration,
        child: decoration == null
            ? body
            : ClipPath(
                clipper: DecorationClipper(
                  decoration: decoration,
                  textDirection: Directionality.maybeOf(context),
                ),
                child: body,
              ),
      ),
    );
  }

  Widget _buildActions(double spacing) {
    return Row(
      children: [
        for (var i = 0; i < leftActions.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          leftActions[i],
        ],
        const Spacer(),
        for (var i = 0; i < rightActions.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          rightActions[i],
        ],
      ],
    );
  }

  /// Recolors the ambient dialog [base] decoration to a plain white surface with
  /// a defined gray border, preserving its shape, radius and shadows.
  Decoration? _plainDecoration(Decoration? base) {
    if (base is ShapeDecoration) {
      final shape = base.shape;
      return ShapeDecoration(
        color: Colors.white,
        shape: shape is OutlinedBorder
            ? shape.copyWith(side: shape.side.copyWith(color: _borderColor, width: 1.5))
            : shape,
        shadows: base.shadows,
        image: base.image,
        gradient: base.gradient,
      );
    }
    if (base is BoxDecoration) {
      return base.copyWith(
        color: Colors.white,
        border: Border.all(color: _borderColor, width: 1.5),
      );
    }
    return base;
  }

}
