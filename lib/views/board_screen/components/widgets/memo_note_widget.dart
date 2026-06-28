import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/widgets/continuous_text_box.dart';
import 'package:h3xboard/widgets/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MemoNoteWidget extends StatelessWidget {

  static const Size naturalSize = Size(300, 300);

  static const _stripColors = {
    MemoNoteColor.yellow: Color(0xFFF9E46B),
    MemoNoteColor.green: Color(0xFF9ED8A0),
    MemoNoteColor.blue: Color(0xFF81C3F0),
    MemoNoteColor.pink: Color(0xFFF39CB5),
  };

  static const _bodyColors = {
    MemoNoteColor.yellow: Color(0xFFFFF9C4),
    MemoNoteColor.green: Color(0xFFC8E6C9),
    MemoNoteColor.blue: Color(0xFFBBDEFB),
    MemoNoteColor.pink: Color(0xFFF8BBD0),
  };

  final String text;
  final MemoNoteColor color;

  const MemoNoteWidget({super.key, this.text = '', this.color = MemoNoteColor.yellow});

  // Renders the note in Patrick Hand — a clean, legible handwriting face that
  // suits a sticky note far better than the default UI font.
  static TextStyle _hand(TextStyle base) => GoogleFonts.patrickHand(textStyle: base);

  // Markdown collapses runs of blank lines into a single paragraph gap, so several
  // Enters in a row would all merge. Giving each blank line a non-breaking space
  // turns it into its own (visible) line, preserving the note's literal spacing
  // (works together with [MarkdownBody.softLineBreak], which keeps single newlines).
  static String _withPreservedBlankLines(String raw) =>
      raw.split('\n').map((line) => line.trim().isEmpty ? ' ' : line).join('\n');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: CustomPaint(
        painter: const _StickyNoteShadowPainter(),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 22, color: _stripColors[color]),
            Expanded(
              child: Container(
                color: _bodyColors[color],
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: text.isEmpty
                    ? const Center(
                        child: Text(
                          'No text',
                          style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 16, fontStyle: FontStyle.italic),
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: 272,
                          child: MarkdownBody(
                            data: _withPreservedBlankLines(text),
                            // Preserve the author's single line breaks instead of
                            // collapsing them into spaces (CommonMark soft breaks).
                            softLineBreak: true,
                            styleSheet: MarkdownStyleSheet(
                              p: _hand(const TextStyle(color: Color(0xFF2D2D2D), fontSize: 20, height: 1.35)),
                              strong: _hand(const TextStyle(color: Color(0xFF2D2D2D), fontSize: 20, fontWeight: FontWeight.bold)),
                              em: _hand(const TextStyle(color: Color(0xFF2D2D2D), fontSize: 20, fontStyle: FontStyle.italic)),
                              h1: _hand(const TextStyle(color: Color(0xFF1A1A1A), fontSize: 28, fontWeight: FontWeight.bold)),
                              h2: _hand(const TextStyle(color: Color(0xFF1A1A1A), fontSize: 24, fontWeight: FontWeight.bold)),
                              h3: _hand(const TextStyle(color: Color(0xFF1A1A1A), fontSize: 21, fontWeight: FontWeight.bold)),
                              listBullet: _hand(const TextStyle(color: Color(0xFF2D2D2D), fontSize: 20)),
                              blockSpacing: 6,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

}

class _StickyNoteShadowPainter extends CustomPainter {

  const _StickyNoteShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x44000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Narrow at top (note is glued via the adhesive strip), wide at bottom (free edge lifts off).
    // The blurred trapezoid produces minimal shadow at the top and a deep shadow at the bottom.
    final path = Path()
      ..moveTo(8, 2)
      ..lineTo(size.width - 8, 2)
      ..lineTo(size.width + 10, size.height + 14)
      ..lineTo(-8, size.height + 11)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

}

class MemoNoteWidgetDescriptor extends BoardWidgetDescriptor {

  static const MemoNoteWidgetDescriptor instance = MemoNoteWidgetDescriptor._();
  const MemoNoteWidgetDescriptor._();

  static const _colorValues = {
    MemoNoteColor.yellow: Color(0xFFFFF9C4),
    MemoNoteColor.green: Color(0xFFC8E6C9),
    MemoNoteColor.blue: Color(0xFFBBDEFB),
    MemoNoteColor.pink: Color(0xFFF8BBD0),
  };

  @override
  IconData get icon => LucideIcons.stickyNote;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_memoNote;

  @override
  Size naturalSize(BoardWidgetConfig config) => MemoNoteWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const MemoNoteConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as MemoNoteConfig;
    return MemoNoteWidget(text: c.text, color: c.color);
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as MemoNoteConfig;
    final loc = context.localizations;

    RadioMenuFlyoutItem<MemoNoteColor> colorItem(MemoNoteColor color, String label) {
      return RadioMenuFlyoutItem<MemoNoteColor>(
        value: color,
        groupValue: c.color,
        text: Text(label),
        trailing: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _colorValues[color],
            border: Border.all(color: const Color(0x44000000), width: 1),
          ),
        ),
        onChanged: (value) => onChange(c.copyWith(color: value)),
      );
    }

    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.pencil, size: 16),
        text: Text(loc.memoNoteSettingsMenu_editText),
        onPressed: () => _showEditDialog(context, c, onChange),
      ),
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.bookOpen, size: 16),
        text: Text(loc.memoNoteSettingsMenu_markdownCheatsheet),
        onPressed: () => _showMarkdownCheatsheetDialog(context),
      ),
      const MenuFlyoutSeparator(),
      colorItem(MemoNoteColor.yellow, loc.memoNoteSettingsMenu_colorYellow),
      colorItem(MemoNoteColor.green, loc.memoNoteSettingsMenu_colorGreen),
      colorItem(MemoNoteColor.blue, loc.memoNoteSettingsMenu_colorBlue),
      colorItem(MemoNoteColor.pink, loc.memoNoteSettingsMenu_colorPink),
    ];
  }

  @override
  VoidCallback? editAction(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) =>
      () => _showEditDialog(context, config as MemoNoteConfig, onChange);

  static void _showMarkdownCheatsheetDialog(BuildContext context) {
    final loc = context.localizations;

    const items = [
      ('# Heading 1', '# Heading 1'),
      ('## Heading 2', '## Heading 2'),
      ('### Heading 3', '### Heading 3'),
      ('**Bold**', '**Bold text**'),
      ('*Italic*', '*Italic text*'),
      ('- item', '- First\n- Second'),
      ('1. item', '1. First\n2. Second'),
    ];

    final mdStyle = MarkdownStyleSheet(
      p: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
      h1: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      h3: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
      strong: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
      em: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF2D2D2D)),
      listBullet: const TextStyle(fontSize: 13, color: Color(0xFF2D2D2D)),
      blockSpacing: 0,
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => ThemableContentDialog(
        title: Text(loc.memoNoteSettingsMenu_markdownCheatsheetDialogTitle),
        constraints: const BoxConstraints(maxWidth: 520),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (syntax, preview) in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x0F000000),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          syntax,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFF444444)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MarkdownBody(data: preview, styleSheet: mdStyle),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.memoNoteSettingsMenu_markdownCheatsheetClose),
          ),
        ],
      ),
    );
  }

  static void _showEditDialog(
    BuildContext context,
    MemoNoteConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final loc = context.localizations;
    final controller = TextEditingController(text: config.text);

    showDialog<void>(
      context: context,
      builder: (ctx) => ThemableContentDialog(
        title: Text(loc.memoNoteSettingsMenu_editTextDialogTitle),
        constraints: const BoxConstraints(maxWidth: 520),
        // Wrapped in a min-sized Column so the multi-line box sizes to its content
        // instead of stretching to fill the dialog's flexible content slot.
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ContinuousTextBox(
              controller: controller,
              maxLines: null,
              minLines: 8,
              placeholder: loc.memoNoteSettingsMenu_editTextPlaceholder,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  LucideIcons.info,
                  size: 14,
                  color: FluentTheme.of(ctx).resources.textFillColorSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  loc.memoNoteSettingsMenu_markdownHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: FluentTheme.of(ctx).resources.textFillColorSecondary,
                  ),
                ),
                HyperlinkButton(
                  // Opens on top of the edit dialog so the in-progress text isn't lost.
                  onPressed: () => _showMarkdownCheatsheetDialog(ctx),
                  child: Text(loc.memoNoteSettingsMenu_markdownHintLink),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.memoNoteSettingsMenu_cancel),
          ),
          FilledButton(
            onPressed: () {
              onChange(config.copyWith(text: controller.text));
              Navigator.of(ctx).pop();
            },
            child: Text(loc.memoNoteSettingsMenu_save),
          ),
        ],
      ),
    );
  }

}
