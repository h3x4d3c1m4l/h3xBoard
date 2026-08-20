import 'package:fluent_ui/fluent_ui.dart';
// Text-selection grab handles, for a touch panel with no mouse to drag with.
// Cupertino, not Material: fluent's own text fields use these too.
import 'package:flutter/cupertino.dart' show cupertinoTextSelectionControls;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:google_fonts/google_fonts.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/color_picker_dialog.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/toggle_button_toolbar.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/rounded_text_highlight.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:h3xboard/views/components/dialogs/dialog_insets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The alignments a label can be set to, in the order their buttons appear.
/// Only visible on a label with more than one line — a single line is exactly as
/// wide as its own text, so there is nothing to align it within.
const List<TextAlign> _alignments = [TextAlign.left, TextAlign.center, TextAlign.right];

const List<IconData> _alignmentIcons = [
  LucideIcons.alignLeft,
  LucideIcons.alignCenter,
  LucideIcons.alignRight,
];

String alignmentLabel(AppLocalizations localizations, TextAlign align) => switch (align) {
      TextAlign.center => localizations.textBoxSettingsMenu_alignCenter,
      TextAlign.right || TextAlign.end => localizations.textBoxSettingsMenu_alignRight,
      _ => localizations.textBoxSettingsMenu_alignLeft,
    };

/// A chrome-less text label: highlighted text sized to its content, with no
/// header bar, dragged around the board by its body.
///
/// Sizing is the delicate part. [ManipulableBoardWidget] reads
/// [BoardWidgetDescriptor.naturalSize] *before* layout and then stretches the
/// child to it with `BoxFit.fill`, so a size that disagrees with what the child
/// actually wants distorts the glyphs rather than clipping them. Two things keep
/// them in agreement:
///
///  * the text is measured at a fixed [contentWidth] and the inner box is pinned
///    to the measured width, so [RoundedTextHighlight] lays out at exactly the
///    width we measured and therefore wraps identically;
///  * [RoundedTextHighlight] sizes itself to the *text* and paints its highlight
///    outside that box, so we add [RoundedTextHighlight.paddingFor] as real
///    padding — otherwise the highlight would be clipped at the edges.
class TextBoxWidget extends StatelessWidget {

  /// Wrapping width for the text, in canvas units (the canvas is 1920×1080).
  static const double contentWidth = 720;

  /// Size used while the text is empty, so the widget stays grabbable and the
  /// catalog preview has something to scale.
  static const Size placeholderSize = Size(420, 130);

  final TextBoxConfig config;

  const TextBoxWidget({super.key, required this.config});

  /// Font family for both measuring and rendering. Normally null, so the style
  /// comes from google_fonts like the rest of the app. Tests set it to keep
  /// google_fonts out of the measurement path — resolving a font there kicks off
  /// an async load that outlives the test and fails it after it has passed.
  @visibleForTesting
  static String? debugFontFamily;

  static TextStyle styleFor(double fontSize, Color color) {
    final base = TextStyle(fontSize: fontSize, color: color, height: 1.3, fontWeight: FontWeight.w600);
    final family = debugFontFamily;
    return family == null ? GoogleFonts.lexend(textStyle: base) : base.copyWith(fontFamily: family);
  }

  /// Lays the text out at [contentWidth] and returns both the raw text box and
  /// the padding the highlight needs around it. The widget and
  /// [TextBoxWidgetDescriptor.naturalSize] both go through this, so what is
  /// measured is exactly what is rendered.
  static ({Size textSize, EdgeInsets padding}) measure(TextBoxConfig config) {
    final painter = RoundedTextHighlight.layoutPainter(
      text: config.text,
      style: styleFor(config.fontSize, config.textColor),
      textAlign: config.textAlign,
      maxWidth: contentWidth,
    );

    final metrics = painter.computeLineMetrics();
    // Every line shares one style here, so a single line height drives the insets.
    final lineHeight = metrics.isEmpty ? config.fontSize : metrics.first.height;

    return (textSize: painter.size, padding: RoundedTextHighlight.paddingFor(lineHeight));
  }

  static Size sizeFor(TextBoxConfig config) {
    if (config.text.trim().isEmpty) return placeholderSize;
    final (:textSize, :padding) = measure(config);
    return Size(textSize.width + padding.horizontal, textSize.height + padding.vertical);
  }

  @override
  Widget build(BuildContext context) {
    if (config.text.trim().isEmpty) {
      return SizedBox.fromSize(
        size: placeholderSize,
        child: Center(
          child: Text(
            context.localizations.textBoxWidget_noText,
            style: styleFor(48, const Color(0xFFAAAAAA)).copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final (:textSize, :padding) = measure(config);

    return Padding(
      padding: padding,
      // Pinned to the measured width so the highlight wraps exactly as measured.
      child: SizedBox(
        width: textSize.width,
        height: textSize.height,
        child: RoundedTextHighlight(
          text: config.text,
          style: styleFor(config.fontSize, config.textColor),
          textAlign: config.textAlign,
          backgroundColor: config.backgroundColor,
        ),
      ),
    );
  }

}

/// Opens the label's editor over the board.
///
/// It borrows a dialog's scrim and keyboard-avoidance but not its card: what
/// floats in the middle is the label itself, at the size and colours it will
/// have on the board, with a caret in it and a style bar underneath. Every
/// change is visible as you make it, so there is nothing left for an OK button
/// to confirm — dismissing keeps the edit, Escape drops it.
///
/// Being a dialog is also what makes this work on a touch panel: the on-screen
/// keyboard pushes the whole thing up instead of covering the label where it
/// happens to sit on the board.
void showTextBoxEditor(
  BuildContext context,
  TextBoxConfig config,
  void Function(BoardWidgetConfig) onChange,
) {
  var draft = config;
  var cancelled = false;

  showAppDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _TextBoxEditor(
      config: config,
      onChanged: (updated) => draft = updated,
      onCancel: () {
        cancelled = true;
        Navigator.of(dialogContext).pop();
      },
    ),
  ).whenComplete(() {
    if (!cancelled && draft != config) onChange(draft);
  });
}

class _TextBoxEditor extends StatefulWidget {

  final TextBoxConfig config;

  /// Reports the working copy on every keystroke and every style change, so the
  /// caller has the final one in hand once the route is gone.
  final ValueChanged<TextBoxConfig> onChanged;

  final VoidCallback onCancel;

  const _TextBoxEditor({
    required this.config,
    required this.onChanged,
    required this.onCancel,
  });

  @override
  State<_TextBoxEditor> createState() => _TextBoxEditorState();

}

class _TextBoxEditorState extends State<_TextBoxEditor> {

  late TextBoxConfig _draft = widget.config;
  late final TextEditingController _controller = TextEditingController(text: widget.config.text)
    // Caret at the end, so editing an existing label continues where it left off
    // rather than in front of it.
    ..selection = TextSelection.collapsed(offset: widget.config.text.length);
  final FocusNode _focusNode = FocusNode();

  void _update(TextBoxConfig config) {
    setState(() => _draft = config);
    widget.onChanged(config);
  }

  Future<void> _pickColor({required bool background}) async {
    final picked = await showColorPicker(
      context,
      initial: background ? _draft.backgroundColor : _draft.textColor,
    );
    if (!mounted) return;
    if (picked != null) {
      _update(background ? _draft.copyWith(backgroundColor: picked) : _draft.copyWith(textColor: picked));
    }
    // The picker took focus with it; hand it back so typing carries on.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return CallbackShortcuts(
      // Escape must reach us before the route's own dismiss handler, which would
      // pop the editor as a save.
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel},
      child: buildDialogInsets(
        context,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // True size, shrunk only when the label is too big for the screen
                // — a size-128 heading is meant to look like one here too.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _EditablePreview(
                      config: _draft,
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: (text) => _update(_draft.copyWith(text: text)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _StyleBar(
                  config: _draft,
                  onChanged: _update,
                  onPickTextColor: () => _pickColor(background: false),
                  onPickBackgroundColor: () => _pickColor(background: true),
                ),
                const SizedBox(height: 12),
                // The only chrome that says how to get out, since there are no
                // buttons to.
                Text(
                  context.localizations.textBoxEditor_dismissHint,
                  textAlign: TextAlign.center,
                  style: theme.typography.caption?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

}

/// The label with a caret in it.
///
/// The visible half *is* [TextBoxWidget] — the same widget the board renders —
/// so the preview cannot drift from what lands on the canvas. On top of it sits
/// an [EditableText] whose own glyphs are transparent: it contributes only the
/// caret, the selection and the keyboard plumbing, aligned to the label's text
/// box so the caret sits between the letters you can see.
///
/// The text is taken from the label rather than from the field, which is why
/// every keystroke is reported upwards: the next frame rebuilds this preview
/// from the new config, and the box grows with the text the way it will on the
/// board.
class _EditablePreview extends StatelessWidget {

  /// [EditableText] keeps a strip of its width free for the caret
  /// (`RenderEditable._caretMargin`: a 1px gap plus the cursor width) and lays
  /// the text out in what is left. Measured text would therefore wrap a word
  /// early here, so the input layer is given that strip on top of it.
  static const double _cursorWidth = 2;
  static const double _caretMargin = 1 + _cursorWidth;

  /// The grey the empty label uses for its "no text" line; the hint borrows it.
  static const Color _hintColor = Color(0xFFAAAAAA);

  final TextBoxConfig config;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _EditablePreview({
    required this.config,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // With nothing typed yet the hint stands in for the label, so the preview is
    // a label taking shape rather than a bare caret on the scrim.
    final isEmpty = config.text.isEmpty;
    final shown = isEmpty
        ? config.copyWith(text: context.localizations.textBoxWidget_typeHint, textColor: _hintColor)
        : config;
    final (:textSize, :padding) = TextBoxWidget.measure(shown);
    // The caret strip lives at the end of every line, so it pushes a centred or
    // right-aligned line inwards; moving the input layer back by that much lines
    // its glyphs up with the label's again.
    final alignShift = switch (config.textAlign) {
      TextAlign.right || TextAlign.end => _caretMargin,
      TextAlign.center => _caretMargin / 2,
      _ => 0.0,
    };

    return SizedBox(
      width: textSize.width + padding.horizontal + _caretMargin,
      height: textSize.height + padding.vertical,
      // A tap on the highlight around the text is aimed at the label, not at the
      // scrim behind it, so it puts the caret back rather than ending the edit.
      // Taps on the text itself are the input layer's; it is hit first.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: focusNode.requestFocus,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TextBoxWidget(config: shown),
            Positioned(
              left: padding.left - alignShift,
              top: padding.top,
              width: textSize.width + _caretMargin,
              height: textSize.height,
              child: EditableText(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                maxLines: null,
                textAlign: config.textAlign,
                keyboardType: TextInputType.multiline,
                // The glyphs below are the label's; this layer only draws a caret.
                style: TextBoxWidget.styleFor(config.fontSize, Colors.transparent),
                cursorColor: isEmpty ? _hintColor : config.textColor,
                cursorWidth: _cursorWidth,
                backgroundCursorColor: _hintColor,
                selectionColor: config.textColor.withValues(alpha: 0.35),
                // Touch panels have no mouse to drag a selection with; these are
                // the grab handles that stand in for one.
                selectionControls: cupertinoTextSelectionControls,
                // The label is measured unscaled, and the caret has to land where
                // those measurements put the glyphs.
                textScaler: TextScaler.noScaling,
                onChanged: onChanged,
                // Tapping the style bar is not "done editing": keep the caret and,
                // on a touch panel, the keyboard.
                onTapOutside: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Colours and alignment for the label being edited, in the same floating bar
/// the board's own tools live in. Every change lands on the preview immediately.
class _StyleBar extends StatelessWidget {

  final TextBoxConfig config;
  final ValueChanged<TextBoxConfig> onChanged;
  final VoidCallback onPickTextColor;
  final VoidCallback onPickBackgroundColor;

  const _StyleBar({
    required this.config,
    required this.onChanged,
    required this.onPickTextColor,
    required this.onPickBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return DecoratedBox(
      decoration: context.appTheme.surfaces.toolbar,
      child: Padding(
        padding: context.appTheme.surfaces.toolbarPadding,
        // Wrapped rather than a Row: on a phone-sized viewport the two groups
        // stack instead of overflowing.
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            ToggleButtonToolbar(
              buttons: [
                _ColorButton(
                  icon: LucideIcons.type,
                  color: config.textColor,
                  tooltip: loc.textBoxSettingsMenu_textColor,
                  onPressed: onPickTextColor,
                ),
                _ColorButton(
                  icon: LucideIcons.paintBucket,
                  color: config.backgroundColor,
                  tooltip: loc.textBoxSettingsMenu_backgroundColor,
                  onPressed: onPickBackgroundColor,
                ),
              ],
            ),
            const Divider(
              direction: Axis.vertical,
              size: 36,
              style: DividerThemeData(
                verticalMargin: EdgeInsets.symmetric(horizontal: 8),
                horizontalMargin: EdgeInsets.zero,
              ),
            ),
            ToggleButtonToolbar(
              buttons: [
                for (var i = 0; i < _alignments.length; i++)
                  Tooltip(
                    message: alignmentLabel(loc, _alignments[i]),
                    child: ToggleButton(
                      checked: config.textAlign == _alignments[i],
                      onChanged: (_) => onChanged(config.copyWith(textAlign: _alignments[i])),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(child: Icon(_alignmentIcons[i], size: 18)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

/// A style-bar button that opens a colour picker, with the colour it currently
/// holds shown as a bar under its glyph — the swatch alone would leave the text
/// and background buttons looking identical.
class _ColorButton extends StatelessWidget {

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ColorButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Tooltip(
      message: tooltip,
      child: Button(
        onPressed: onPressed,
        child: SizedBox(
          width: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Icon(icon, size: 18),
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2.5),
                  // Keeps a white (or board-coloured) swatch readable on the bar.
                  border: Border.all(color: theme.resources.controlStrokeColorDefault),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class TextBoxWidgetDescriptor extends BoardWidgetDescriptor {

  static const TextBoxWidgetDescriptor instance = TextBoxWidgetDescriptor._();
  const TextBoxWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.type;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_textBox;

  @override
  Size naturalSize(BoardWidgetConfig config) => TextBoxWidget.sizeFor(config as TextBoxConfig);

  @override
  BoardWidgetConfig get defaultConfig => const TextBoxConfig();

  // Added from its own button in the annotation toolbar, not the catalog.
  @override
  bool get showInCatalog => false;

  // A bare label reads as text on the board, not as a boxed widget, so it skips
  // the header bar. Move, settings and delete come from body drag, double-click
  // and the long-press / right-click menu instead.
  @override
  bool get hasHeaderBar => false;

  @override
  bool get isDraggableInSelectMode => true;

  // Without a header there is no pencil toggle, so tapping the label is what
  // brings out its resize and rotate handles.
  @override
  bool get entersArrangeOnTap => true;

  // A label reads as text on the board rather than as a widget being worked on,
  // so it is not dimmed while it is arranged.
  @override
  bool get isInertWhileArranging => false;

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    return TextBoxWidget(config: config as TextBoxConfig);
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as TextBoxConfig;
    final loc = context.localizations;

    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.pencil, size: 16),
        text: Text(loc.textBoxSettingsMenu_editText),
        onPressed: () => showTextBoxEditor(context, c, onChange),
      ),
      const MenuFlyoutSeparator(),
      MenuFlyoutItem(
        leading: _swatch(c.textColor),
        text: Text(loc.textBoxSettingsMenu_textColor),
        onPressed: () async {
          final picked = await showColorPicker(context, initial: c.textColor);
          if (picked != null) onChange(c.copyWith(textColor: picked));
        },
      ),
      MenuFlyoutItem(
        leading: _swatch(c.backgroundColor),
        text: Text(loc.textBoxSettingsMenu_backgroundColor),
        onPressed: () async {
          final picked = await showColorPicker(context, initial: c.backgroundColor);
          if (picked != null) onChange(c.copyWith(backgroundColor: picked));
        },
      ),
      const MenuFlyoutSeparator(),
      for (final align in _alignments)
        RadioMenuFlyoutItem<TextAlign>(
          value: align,
          groupValue: c.textAlign,
          text: Text(alignmentLabel(loc, align)),
          onChanged: (value) => onChange(c.copyWith(textAlign: value)),
        ),
    ];
  }

  static Widget _swatch(Color color) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: const Color(0x44000000)),
        ),
      );

  @override
  VoidCallback? editAction(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) =>
      () => showTextBoxEditor(context, config as TextBoxConfig, onChange);

}
