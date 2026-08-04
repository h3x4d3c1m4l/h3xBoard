import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/components/auth_panel.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:h3xboard/views/verify_email_screen/verify_email_screen_controller.dart';
import 'package:h3xboard/views/verify_email_screen/verify_email_screen_view_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VerifyEmailScreenView extends ScreenViewBase<VerifyEmailScreenViewModel, VerifyEmailScreenController> {

  const VerifyEmailScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    return Observer(
      builder: (context) => switch (viewModel.status) {
        VerifyEmailStatus.verifying => _buildVerifying(),
        VerifyEmailStatus.invalidToken => _buildInvalidToken(),
        VerifyEmailStatus.rateLimited => _buildRateLimited(),
        VerifyEmailStatus.failed => _buildFailed(),
      },
    );
  }

  Widget _buildVerifying() {
    return AuthPanel(
      icon: LucideIcons.mailCheck,
      title: localizations.verifyEmailScreen_verifyingTitle,
      children: const [
        Center(child: SizedBox(width: 24, height: 24, child: ProgressRing(strokeWidth: 3))),
      ],
    );
  }

  Widget _buildInvalidToken() {
    return AuthPanel(
      icon: LucideIcons.mailX,
      iconColor: ThemableDialogSeverity.warning.primaryColor,
      title: localizations.verifyEmailScreen_invalidTitle,
      message: localizations.verifyEmailScreen_invalidMessage,
      children: [
        FilledButton(
          onPressed: controller.onRequestNewLink,
          child: Text(localizations.verifyEmailScreen_requestNewLink),
        ),
        _backToSignIn(),
      ],
    );
  }

  Widget _buildRateLimited() {
    return AuthPanel(
      icon: LucideIcons.hourglass,
      iconColor: ThemableDialogSeverity.warning.primaryColor,
      title: localizations.verifyEmailScreen_rateLimitedTitle,
      message: localizations.verifyEmailScreen_rateLimitedMessage,
      children: [_retry(), _backToSignIn()],
    );
  }

  Widget _buildFailed() {
    return AuthPanel(
      icon: LucideIcons.triangleAlert,
      iconColor: ThemableDialogSeverity.error.primaryColor,
      title: localizations.verifyEmailScreen_failedTitle,
      message: localizations.verifyEmailScreen_failedMessage,
      children: [_retry(), _backToSignIn()],
    );
  }

  // Retrying is always a deliberate tap: a rate limit that retries itself is
  // just a slower way of staying rate-limited.
  Widget _retry() => FilledButton(
    onPressed: controller.verify,
    child: Text(localizations.verifyEmailScreen_retry),
  );

  Widget _backToSignIn() => Button(
    onPressed: controller.onBackToSignIn,
    child: Text(localizations.verifyEmailScreen_backToSignIn, textAlign: TextAlign.center),
  );

}
