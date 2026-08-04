import 'package:fluent_ui/fluent_ui.dart';

/// The centred card every account-lifecycle screen is built from — verifying a
/// mailed link, choosing a new password, confirming an address change.
///
/// These screens are the first (and sometimes only) thing a user sees of the
/// app, often arriving cold from an e-mail, so they share one shape: an icon,
/// a title, a line of explanation, and whatever actions the situation calls
/// for. The 360px column matches the login screen, which the user is on their
/// way to or from.
class AuthPanel extends StatelessWidget {

  final IconData icon;

  /// Tint of the icon and the disc behind it. Defaults to the accent color;
  /// pass a status color to flag an expired link or a failure.
  final Color? iconColor;

  final String title;

  /// The explanatory line under the title. Optional — a bare "working on it"
  /// state has nothing useful to add.
  final String? message;

  /// Buttons, fields and info bars, stacked below the message.
  final List<Widget> children;

  const AuthPanel({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.message,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = iconColor ?? theme.accentColor;
    return ScaffoldPage(
      content: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 26, color: color),
                  ),
                ),
                Text(title, style: theme.typography.title, textAlign: TextAlign.center),
                if (message != null)
                  Text(
                    message!,
                    style: theme.typography.body?.copyWith(color: theme.resources.textFillColorSecondary),
                    textAlign: TextAlign.center,
                  ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

}
