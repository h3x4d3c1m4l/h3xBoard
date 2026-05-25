import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/login_screen/login_screen_controller.dart';
import 'package:h3xboard/views/login_screen/login_screen_view_model.dart';

class LoginScreenView extends ScreenViewBase<LoginScreenViewModel, LoginScreenController> {

  const LoginScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    return ScaffoldPage(
      content: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Observer(
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Text(
                  viewModel.isRegisterMode
                      ? localizations.loginScreen_createAccount
                      : localizations.loginScreen_signIn,
                  style: FluentTheme.of(context).typography.title,
                  textAlign: TextAlign.center,
                ),
                TextBox(
                  controller: viewModel.emailController,
                  placeholder: localizations.loginScreen_email,
                  enabled: !viewModel.isLoading,
                ),
                TextBox(
                  controller: viewModel.passwordController,
                  placeholder: localizations.loginScreen_password,
                  obscureText: true,
                  enabled: !viewModel.isLoading,
                  onSubmitted: (_) => controller.submit(),
                ),
                if (viewModel.errorMessage != null)
                  InfoBar(
                    title: Text(viewModel.errorMessage!),
                    severity: InfoBarSeverity.error,
                  ),
                FilledButton(
                  onPressed: viewModel.isLoading ? null : controller.submit,
                  child: viewModel.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      : Text(
                          viewModel.isRegisterMode
                              ? localizations.loginScreen_createAccountButton
                              : localizations.loginScreen_signInButton,
                        ),
                ),
                Button(
                  onPressed: viewModel.isLoading ? null : controller.toggleMode,
                  child: Text(
                    viewModel.isRegisterMode
                        ? localizations.loginScreen_switchToLogin
                        : localizations.loginScreen_switchToRegister,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
