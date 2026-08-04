import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/components/auth_panel.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/unverified_screen/unverified_screen_controller.dart';
import 'package:h3xboard/views/unverified_screen/unverified_screen_view_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class UnverifiedScreenView extends ScreenViewBase<UnverifiedScreenViewModel, UnverifiedScreenController> {

  const UnverifiedScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    return Observer(
      builder: (context) {
        final email = viewModel.email;
        return AuthPanel(
          icon: LucideIcons.mailCheck,
          title: localizations.unverifiedScreen_title,
          message: email != null
              ? localizations.unverifiedScreen_messageWithEmail(email)
              : localizations.unverifiedScreen_messageWithoutEmail,
          children: [
            Text(
              localizations.unverifiedScreen_spamHint,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: FluentTheme.of(context).resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            // With no address to go on there is nothing to resend to, so ask
            // for one; when we do know it, showing the field again would only
            // invite a typo.
            if (email == null)
              ContinuousTextBox(
                controller: viewModel.emailController,
                placeholder: localizations.unverifiedScreen_emailPlaceholder,
                enabled: !viewModel.isSending,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => controller.resendVerification(),
              ),
            if (viewModel.hasRequestedResend)
              InfoBar(
                title: Text(localizations.unverifiedScreen_resendRequested),
                severity: InfoBarSeverity.success,
                isLong: true,
              ),
            if (viewModel.errorMessage != null)
              InfoBar(
                title: Text(viewModel.errorMessage!),
                severity: InfoBarSeverity.error,
                isLong: true,
              ),
            FilledButton(
              onPressed: viewModel.isSending ? null : controller.resendVerification,
              child: viewModel.isSending
                  ? const SizedBox(width: 20, height: 20, child: ProgressRing(strokeWidth: 2))
                  : Text(localizations.unverifiedScreen_resend),
            ),
            Button(
              onPressed: controller.onBackToSignIn,
              child: Text(localizations.unverifiedScreen_backToSignIn, textAlign: TextAlign.center),
            ),
          ],
        );
      },
    );
  }

}
