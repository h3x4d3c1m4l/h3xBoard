import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/components/auth_panel.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:h3xboard/views/confirm_email_change_screen/confirm_email_change_screen_controller.dart';
import 'package:h3xboard/views/confirm_email_change_screen/confirm_email_change_screen_view_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ConfirmEmailChangeScreenView
    extends ScreenViewBase<ConfirmEmailChangeScreenViewModel, ConfirmEmailChangeScreenController> {

  const ConfirmEmailChangeScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    return Observer(
      builder: (context) => switch (viewModel.status) {
        ConfirmEmailChangeStatus.confirming => _buildConfirming(),
        ConfirmEmailChangeStatus.confirmed => _buildConfirmed(),
        ConfirmEmailChangeStatus.invalidToken => _buildInvalidToken(),
        ConfirmEmailChangeStatus.addressTaken => _buildAddressTaken(),
        ConfirmEmailChangeStatus.rateLimited => _buildRateLimited(),
        ConfirmEmailChangeStatus.failed => _buildFailed(),
      },
    );
  }

  Widget _buildConfirming() {
    return AuthPanel(
      icon: LucideIcons.mailCheck,
      title: localizations.confirmEmailChangeScreen_confirmingTitle,
      children: const [
        Center(child: SizedBox(width: 24, height: 24, child: ProgressRing(strokeWidth: 3))),
      ],
    );
  }

  Widget _buildConfirmed() {
    return AuthPanel(
      icon: LucideIcons.circleCheck,
      iconColor: Colors.successPrimaryColor,
      title: localizations.confirmEmailChangeScreen_confirmedTitle,
      message: localizations.confirmEmailChangeScreen_confirmedMessage(viewModel.email ?? ''),
      children: [_continue(primary: true)],
    );
  }

  Widget _buildInvalidToken() {
    return AuthPanel(
      icon: LucideIcons.mailX,
      iconColor: ThemableDialogSeverity.warning.primaryColor,
      title: localizations.confirmEmailChangeScreen_invalidTitle,
      message: localizations.confirmEmailChangeScreen_invalidMessage,
      children: [_continue(primary: true)],
    );
  }

  Widget _buildAddressTaken() {
    return AuthPanel(
      icon: LucideIcons.atSign,
      iconColor: ThemableDialogSeverity.warning.primaryColor,
      title: localizations.confirmEmailChangeScreen_takenTitle,
      message: localizations.confirmEmailChangeScreen_takenMessage,
      children: [_continue(primary: true)],
    );
  }

  Widget _buildRateLimited() {
    return AuthPanel(
      icon: LucideIcons.hourglass,
      iconColor: ThemableDialogSeverity.warning.primaryColor,
      title: localizations.confirmEmailChangeScreen_rateLimitedTitle,
      message: localizations.confirmEmailChangeScreen_rateLimitedMessage,
      children: [_retry(), _continue()],
    );
  }

  Widget _buildFailed() {
    return AuthPanel(
      icon: LucideIcons.triangleAlert,
      iconColor: ThemableDialogSeverity.error.primaryColor,
      title: localizations.confirmEmailChangeScreen_failedTitle,
      message: localizations.confirmEmailChangeScreen_failedMessage,
      children: [_retry(), _continue()],
    );
  }

  // Retrying is always a deliberate tap: a rate limit that retries itself is
  // just a slower way of staying rate-limited.
  Widget _retry() => FilledButton(
    onPressed: controller.confirm,
    child: Text(localizations.confirmEmailChangeScreen_retry),
  );

  // The only way off this screen, so it leads when nothing else competes and
  // steps back to a plain button when a retry is the obvious next move.
  Widget _continue({bool primary = false}) {
    final label = Text(localizations.confirmEmailChangeScreen_continue, textAlign: TextAlign.center);
    return primary
        ? FilledButton(onPressed: controller.onContinue, child: label)
        : Button(onPressed: controller.onContinue, child: label);
  }

}
