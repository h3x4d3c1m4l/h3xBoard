import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';

/// Opens the "change e-mail address" dialog from account settings.
Future<void> showChangeEmailDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (_) => const ChangeEmailDialog(),
);

/// Starts an address change: the account keeps its current address until the
/// confirmation link mailed to the new one is opened.
///
/// The password is required and is not politeness — without it a stolen session
/// cookie would be enough to move the account to somebody else's mailbox.
class ChangeEmailDialog extends StatefulWidget {

  const ChangeEmailDialog({super.key});

  @override
  State<ChangeEmailDialog> createState() => _ChangeEmailDialogState();

}

class _ChangeEmailDialogState extends State<ChangeEmailDialog> {

  final _auth = GetIt.I<H3xBoardAuthService>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _sending = false;

  /// The address the confirmation went to, set once the request is accepted.
  String? _sentTo;

  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = context.localizations;
    final email = _emailController.text.trim();
    if (email.isEmpty || _passwordController.text.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _auth.changeEmail(newEmail: email, currentPassword: _passwordController.text);
      if (mounted) setState(() => _sentTo = email);
    } on H3xBoardApiException catch (e) {
      if (mounted) {
        setState(() => _error = switch (e.code) {
          401 => loc.changeEmailDialog_wrongPassword,
          409 => loc.changeEmailDialog_taken,
          400 => loc.changeEmailDialog_sameAsCurrent,
          429 => loc.changeEmailDialog_rateLimited,
          _ => loc.changeEmailDialog_failed,
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = loc.changeEmailDialog_failed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    final sentTo = _sentTo;
    return ThemableContentDialog(
      title: Text(loc.changeEmailDialog_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: sentTo != null
            ? [
                InfoBar(
                  title: Text(loc.changeEmailDialog_sent(sentTo)),
                  severity: InfoBarSeverity.success,
                  isLong: true,
                ),
              ]
            : [
                Text(loc.changeEmailDialog_message),
                ContinuousTextBox(
                  controller: _emailController,
                  placeholder: loc.changeEmailDialog_newEmail,
                  enabled: !_sending,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                ContinuousTextBox(
                  controller: _passwordController,
                  placeholder: loc.changeEmailDialog_currentPassword,
                  obscureText: true,
                  enabled: !_sending,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => unawaited(_submit()),
                ),
                if (_error != null)
                  InfoBar(title: Text(_error!), severity: InfoBarSeverity.error, isLong: true),
              ],
      ),
      actions: sentTo != null
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(loc.changeEmailDialog_close),
              ),
            ]
          : [
              Button(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: Text(loc.changeEmailDialog_cancel),
              ),
              FilledButton(
                onPressed: _sending ? null : () => unawaited(_submit()),
                child: Text(loc.changeEmailDialog_submit),
              ),
            ],
    );
  }

}
