import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';

/// A loading indicator styled like a [ThemableContentDialog]: a themed card
/// (rounded corners, accent tint, animated background pattern) holding a spinner
/// and a message laid out side by side.
class ThemableLoadingDialog extends StatelessWidget {

  /// Creates a themable loading dialog.
  const ThemableLoadingDialog({
    super.key,
    required this.message,
    this.subtitle,
    this.showBackgroundPattern = true,
  });

  /// The primary loading message, shown next to the spinner.
  final String message;

  /// Optional secondary line shown beneath [message] (e.g. a retry count).
  final String? subtitle;

  /// Whether to paint the animated background pattern. Defaults to `true`.
  final bool showBackgroundPattern;

  @override
  Widget build(BuildContext context) {

    return ThemableContentDialog(
      showBackgroundPattern: showBackgroundPattern,
      // Size to its content rather than stretching to the default dialog width.
      constraints: const BoxConstraints(maxWidth: 368),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProgressRing(),
            const SizedBox(width: 24),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (subtitle != null) Text(subtitle!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
