import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/services/live_share/live_view_client.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';

/// Asks for a live-share code — the "log in to a second screen" step, from the
/// login screen, the boards overview and the viewer itself.
///
/// Returns the code in the canonical form the viewer connects with (see
/// [LiveViewClient.normalizeCode]), or `null` when the dialog was dismissed. An
/// empty field can't be submitted, so a non-null result is always a code worth
/// trying.
Future<String?> showWatchCodeDialog(BuildContext context) async {
  final loc = context.localizations;
  final textController = TextEditingController();
  try {
    return await showAppDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {

        void submit() {
          final code = LiveViewClient.normalizeCode(textController.text);
          if (code.isNotEmpty) Navigator.of(ctx).pop(code);
        }

        return ThemableContentDialog(
          title: Text(loc.viewerScreen_title),
          constraints: const BoxConstraints(maxWidth: 460),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.viewerScreen_codeDescription),
              const SizedBox(height: 12),
              ContinuousTextBox(
                controller: textController,
                placeholder: loc.viewerScreen_codePlaceholder,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.viewerScreen_codeCancel),
            ),
            FilledButton(
              onPressed: submit,
              child: Text(loc.viewerScreen_watch),
            ),
          ],
        );
      },
    );
  } finally {
    textController.dispose();
  }
}
