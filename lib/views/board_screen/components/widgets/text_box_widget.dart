import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/color_picker_dialog.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rounded_background_text/rounded_background_text.dart';

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
///    to the measured width, so [RoundedBackgroundText] lays out at exactly the
///    width we measured and therefore wraps identically;
///  * [RoundedBackgroundText] reports only the *text* size and paints its
///    background outside that box, so we add the same insets it uses as real
///    padding — otherwise the highlight would be clipped at the edges.
class TextBoxWidget extends StatelessWidget {

  /// Wrapping width for the text, in canvas units (the canvas is 1920×1080).
  static const double contentWidth = 720;

  /// Size used while the text is empty, so the widget stays grabbable and the
  /// catalog preview has something to scale.
  static const Size placeholderSize = Size(420, 130);

  /// The background insets [RoundedBackgroundTextPainter] paints outside the
  /// text box, as factors of the line height. Mirrors `_firstLinePadding` /
  /// `_lastLinePadding` in the package: 0.3 on the sides and top, 0.175/2 at the
  /// bottom. Overshooting here would only add invisible margin; undershooting
  /// clips the highlight, so these are deliberately exact.
  static const double _sidePaddingFactor = 0.3;
  static const double _topPaddingFactor = 0.3;
  static const double _bottomPaddingFactor = 0.175 / 2;

  final String text;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;

  const TextBoxWidget({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
  });

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
    final painter = TextPainter(
      text: TextSpan(text: config.text, style: styleFor(config.fontSize, config.textColor)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: contentWidth);

    final metrics = painter.computeLineMetrics();
    // Every line shares one style here, so a single line height drives the insets.
    final lineHeight = metrics.isEmpty ? config.fontSize : metrics.first.height;

    return (
      textSize: painter.size,
      padding: EdgeInsets.only(
        left: lineHeight * _sidePaddingFactor,
        right: lineHeight * _sidePaddingFactor,
        top: lineHeight * _topPaddingFactor,
        bottom: lineHeight * _bottomPaddingFactor,
      ),
    );
  }

  static Size sizeFor(TextBoxConfig config) {
    if (config.text.trim().isEmpty) return placeholderSize;
    final (:textSize, :padding) = measure(config);
    return Size(textSize.width + padding.horizontal, textSize.height + padding.vertical);
  }

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
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

    final config = TextBoxConfig(
      text: text,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: fontSize,
    );
    final (:textSize, :padding) = measure(config);

    return Padding(
      padding: padding,
      // Pinned to the measured width so the package wraps exactly as measured.
      child: SizedBox(
        width: textSize.width,
        height: textSize.height,
        child: RoundedBackgroundText(
          text,
          style: styleFor(fontSize, textColor),
          backgroundColor: backgroundColor,
          // The package caps both radii at 20; this is as close to the app's
          // squircles as it can get (its corners are circular arcs, not
          // continuous curves).
          innerRadius: 20,
          outerRadius: 20,
        ),
      ),
    );
  }

}

class TextBoxWidgetDescriptor extends BoardWidgetDescriptor {

  static const TextBoxWidgetDescriptor instance = TextBoxWidgetDescriptor._();
  const TextBoxWidgetDescriptor._();

  static const _fontSizes = [32.0, 48.0, 64.0, 96.0, 128.0];

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

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as TextBoxConfig;
    return TextBoxWidget(
      text: c.text,
      backgroundColor: c.backgroundColor,
      textColor: c.textColor,
      fontSize: c.fontSize,
    );
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
        onPressed: () => _showEditDialog(context, c, onChange),
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
      for (final size in _fontSizes)
        RadioMenuFlyoutItem<double>(
          value: size,
          groupValue: c.fontSize,
          text: Text(loc.textBoxSettingsMenu_fontSizeValue(size.round())),
          onChanged: (value) => onChange(c.copyWith(fontSize: value)),
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
      () => _showEditDialog(context, config as TextBoxConfig, onChange);

  static void _showEditDialog(
    BuildContext context,
    TextBoxConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final loc = context.localizations;
    final controller = TextEditingController(text: config.text);

    showDialog<void>(
      context: context,
      builder: (ctx) => ThemableContentDialog(
        title: Text(loc.textBoxSettingsMenu_editTextDialogTitle),
        constraints: const BoxConstraints(maxWidth: 520),
        // Min-sized so the multi-line box hugs its content instead of stretching
        // to fill the dialog's flexible content slot.
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ContinuousTextBox(
              controller: controller,
              autofocus: true,
              maxLines: null,
              minLines: 4,
              placeholder: loc.textBoxSettingsMenu_editTextPlaceholder,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.textBoxSettingsMenu_cancel),
          ),
          FilledButton(
            onPressed: () {
              onChange(config.copyWith(text: controller.text));
              Navigator.of(ctx).pop();
            },
            child: Text(loc.textBoxSettingsMenu_save),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

}
