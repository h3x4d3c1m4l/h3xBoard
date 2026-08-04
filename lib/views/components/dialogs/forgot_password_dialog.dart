import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';

/// Opens the "reset your password" dialog. Reachable from the login screen and
/// from the reset screen when its link turned out to be dead.
///
/// [useRootNavigator] follows `showDialog`'s default; pass `false` when opening
/// from inside a flyout so the dialog lands on the navigator the flyout is
/// dismissing on.
Future<void> showForgotPasswordDialog(
  BuildContext context, {
  String? initialEmail,
  bool useRootNavigator = true,
}) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  useRootNavigator: useRootNavigator,
  builder: (_) => ForgotPasswordDialog(initialEmail: initialEmail),
);

/// Asks for an address and requests a password-reset link for it.
///
/// The server answers `202` whether or not the account exists, so this dialog
/// has nothing to report either way — and says so in one fixed sentence. Any
/// "no account with that address" here would hand out an existence oracle the
/// server deliberately withholds.
class ForgotPasswordDialog extends StatefulWidget {

  /// Pre-fills the field with whatever the user already typed on the login
  /// screen, so they do not type their address twice.
  final String? initialEmail;

  const ForgotPasswordDialog({super.key, this.initialEmail});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();

}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {

  final _auth = GetIt.I<H3xBoardAuthService>();
  late final TextEditingController _emailController = TextEditingController(text: widget.initialEmail);

  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _auth.forgotPassword(email);
      if (mounted) setState(() => _sent = true);
    } on H3xBoardApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.code == 429
            ? context.localizations.forgotPasswordDialog_rateLimited
            : context.localizations.forgotPasswordDialog_failed);
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.localizations.forgotPasswordDialog_failed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    return ThemableContentDialog(
      title: Text(loc.forgotPasswordDialog_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: _sent
            ? [
                InfoBar(
                  title: Text(loc.forgotPasswordDialog_sent),
                  severity: InfoBarSeverity.success,
                  isLong: true,
                ),
              ]
            : [
                Text(loc.forgotPasswordDialog_message),
                ContinuousTextBox(
                  controller: _emailController,
                  placeholder: loc.forgotPasswordDialog_email,
                  enabled: !_sending,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => unawaited(_send()),
                ),
                if (_error != null)
                  InfoBar(title: Text(_error!), severity: InfoBarSeverity.error, isLong: true),
              ],
      ),
      actions: _sent
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(loc.forgotPasswordDialog_close),
              ),
            ]
          : [
              Button(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: Text(loc.forgotPasswordDialog_cancel),
              ),
              FilledButton(
                onPressed: _sending ? null : () => unawaited(_send()),
                child: Text(loc.forgotPasswordDialog_submit),
              ),
            ],
    );
  }

}
