import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/components/auth_panel.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:h3xboard/views/reset_password_screen/reset_password_screen_controller.dart';
import 'package:h3xboard/views/reset_password_screen/reset_password_screen_view_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ResetPasswordScreenView extends ScreenViewBase<ResetPasswordScreenViewModel, ResetPasswordScreenController> {

  const ResetPasswordScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    return Observer(
      builder: (context) => viewModel.isLinkDead ? _buildLinkDead() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return AuthPanel(
      icon: LucideIcons.keyRound,
      title: localizations.resetPasswordScreen_title,
      message: localizations.resetPasswordScreen_message,
      children: [
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              ContinuousTextBox(
                controller: viewModel.passwordController,
                placeholder: localizations.resetPasswordScreen_newPassword,
                obscureText: true,
                enabled: !viewModel.isSubmitting,
                autofocus: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              ContinuousTextBox(
                controller: viewModel.confirmPasswordController,
                placeholder: localizations.resetPasswordScreen_confirmPassword,
                obscureText: true,
                enabled: !viewModel.isSubmitting,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => controller.submit(),
                autofillHints: const [AutofillHints.newPassword],
              ),
            ],
          ),
        ),
        if (viewModel.errorMessage != null)
          InfoBar(title: Text(viewModel.errorMessage!), severity: InfoBarSeverity.error, isLong: true),
        FilledButton(
          onPressed: viewModel.isSubmitting ? null : controller.submit,
          child: viewModel.isSubmitting
              ? const SizedBox(width: 20, height: 20, child: ProgressRing(strokeWidth: 2))
              : Text(localizations.resetPasswordScreen_submit),
        ),
        _backToSignIn(),
      ],
    );
  }

  Widget _buildLinkDead() {
    return AuthPanel(
      icon: LucideIcons.mailX,
      iconColor: ThemableDialogSeverity.warning.primaryColor,
      title: localizations.resetPasswordScreen_invalidTitle,
      message: localizations.resetPasswordScreen_invalidMessage,
      children: [
        FilledButton(
          onPressed: controller.onRequestNewLink,
          child: Text(localizations.resetPasswordScreen_requestNewLink),
        ),
        _backToSignIn(),
      ],
    );
  }

  Widget _backToSignIn() => Button(
    onPressed: controller.onBackToSignIn,
    child: Text(localizations.resetPasswordScreen_backToSignIn, textAlign: TextAlign.center),
  );

}
