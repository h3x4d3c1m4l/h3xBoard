import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/widgets/continuous_text_box.dart';
import 'package:h3xboard/widgets/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A tappable chip showing which server the app is connected to and
/// opening the "change server URL" dialog.
class ServerChip extends StatelessWidget {

  final String serverUrl;
  final VoidCallback? onEdit;

  const ServerChip({
    super.key,
    required this.serverUrl,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {

    final theme = FluentTheme.of(context);
    final host = _hostOf(serverUrl);
    return Align(
      child: HyperlinkButton(
        onPressed: onEdit,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.server, size: 14, color: theme.resources.textFillColorSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.localizations.serverChip_serverLabel(host),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Strips the scheme so the chip reads as a compact host (falls back to the
  /// full string when it can't be parsed).
  static String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

}

/// Prompts for a new server URL, pre-filled with [currentUrl], and hands the
/// trimmed result to [onSave] (never called with an empty string).
void showServerUrlDialog(
  BuildContext context, {
  required String currentUrl,
  required ValueChanged<String> onSave,
}) {
  final loc = context.localizations;
  final textController = TextEditingController(text: currentUrl);

  void applyAndClose(BuildContext ctx) {
    final trimmed = textController.text.trim();
    if (trimmed.isNotEmpty) onSave(trimmed);
    Navigator.of(ctx).pop();
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => ThemableContentDialog(
      title: Text(loc.serverUrlDialog_title),
      constraints: const BoxConstraints(maxWidth: 460),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(loc.serverUrlDialog_subtitle),
          const SizedBox(height: 12),
          ContinuousTextBox(
            controller: textController,
            placeholder: loc.serverUrlDialog_placeholder,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => applyAndClose(ctx),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(loc.serverUrlDialog_cancel),
        ),
        FilledButton(
          onPressed: () => applyAndClose(ctx),
          child: Text(loc.serverUrlDialog_save),
        ),
      ],
    ),
  );
}
