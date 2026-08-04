import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';

/// The shortest password the server accepts. Checked here too, so a 400 from
/// the server can only mean the one thing this dialog cannot check itself: the
/// new password is the same as the current one.
const int kMinPasswordLength = 8;

/// Opens the "change password" dialog from account settings.
Future<void> showChangePasswordDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (_) => const ChangePasswordDialog(),
);

/// Changes the signed-in user's password.
///
/// The current password is asked for even though a session is already open: it
/// is the only thing standing between a borrowed, unlocked laptop and a
/// take-over. The session survives the change — the user is at the keyboard and
/// just proved it — so nothing here signs anyone out.
class ChangePasswordDialog extends StatefulWidget {

  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();

}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {

  final _auth = GetIt.I<H3xBoardAuthService>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _saving = false;
  bool _changed = false;
  String? _error;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loc = context.localizations;
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    if (next.length < kMinPasswordLength) {
      setState(() => _error = loc.changePasswordDialog_tooShort);
      return;
    }
    if (next != _confirmPasswordController.text) {
      setState(() => _error = loc.changePasswordDialog_mismatch);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _auth.changePassword(currentPassword: current, newPassword: next);
      if (mounted) setState(() => _changed = true);
    } on H3xBoardApiException catch (e) {
      if (mounted) {
        setState(() => _error = switch (e.code) {
          401 => loc.changePasswordDialog_wrongPassword,
          // Length is already checked above, so this is the other 400.
          400 => loc.changePasswordDialog_sameAsCurrent,
          429 => loc.changePasswordDialog_rateLimited,
          _ => loc.changePasswordDialog_failed,
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = loc.changePasswordDialog_failed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    return ThemableContentDialog(
      title: Text(loc.changePasswordDialog_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: _changed
            ? [
                InfoBar(
                  title: Text(loc.changePasswordDialog_changed),
                  severity: InfoBarSeverity.success,
                  isLong: true,
                ),
              ]
            : [
                ContinuousTextBox(
                  controller: _currentPasswordController,
                  placeholder: loc.changePasswordDialog_currentPassword,
                  obscureText: true,
                  enabled: !_saving,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                ),
                ContinuousTextBox(
                  controller: _newPasswordController,
                  placeholder: loc.changePasswordDialog_newPassword,
                  obscureText: true,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                ),
                ContinuousTextBox(
                  controller: _confirmPasswordController,
                  placeholder: loc.changePasswordDialog_confirmPassword,
                  obscureText: true,
                  enabled: !_saving,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => unawaited(_submit()),
                ),
                if (_error != null)
                  InfoBar(title: Text(_error!), severity: InfoBarSeverity.error, isLong: true),
              ],
      ),
      actions: _changed
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(loc.changePasswordDialog_close),
              ),
            ]
          : [
              Button(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(loc.changePasswordDialog_cancel),
              ),
              FilledButton(
                onPressed: _saving ? null : () => unawaited(_submit()),
                child: Text(loc.changePasswordDialog_submit),
              ),
            ],
    );
  }

}
