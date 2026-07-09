import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/models/api/server_info.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/login_screen/login_screen_controller.dart';
import 'package:h3xboard/views/login_screen/login_screen_view_model.dart';
import 'package:h3xboard/widgets/continuous_text_box.dart';
import 'package:h3xboard/widgets/server_chip.dart';

class LoginScreenView extends ScreenViewBase<LoginScreenViewModel, LoginScreenController> {

  const LoginScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    final server = GetIt.I<ServerController>();
    return ScaffoldPage(
      content: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ValueListenableBuilder<ServerInfo?>(
            valueListenable: server.serverInfo,
            builder: (context, serverInfo, _) => Observer(
              builder: (context) {
                return AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      if (serverInfo?.warning != null)
                        InfoBar(
                          title: Text(serverInfo!.warning!),
                          severity: InfoBarSeverity.warning,
                          isLong: true,
                        ),
                      Text(
                        viewModel.isRegisterMode
                            ? localizations.loginScreen_createAccount
                            : localizations.loginScreen_signIn,
                        style: FluentTheme.of(context).typography.title,
                        textAlign: TextAlign.center,
                      ),
                      if (viewModel.isRegisterMode) ...[
                        ContinuousTextBox(
                          controller: viewModel.firstNameController,
                          placeholder: localizations.loginScreen_firstName,
                          enabled: !viewModel.isLoading,
                          keyboardType: TextInputType.name,
                          autofillHints: const [AutofillHints.givenName],
                        ),
                        ContinuousTextBox(
                          controller: viewModel.lastNameController,
                          placeholder: localizations.loginScreen_lastName,
                          enabled: !viewModel.isLoading,
                          keyboardType: TextInputType.name,
                          autofillHints: const [AutofillHints.familyName],
                        ),
                      ],
                      ContinuousTextBox(
                        controller: viewModel.emailController,
                        placeholder: localizations.loginScreen_email,
                        enabled: !viewModel.isLoading,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        textInputAction: TextInputAction.next,
                      ),
                      ContinuousTextBox(
                        controller: viewModel.passwordController,
                        placeholder: localizations.loginScreen_password,
                        obscureText: true,
                        enabled: !viewModel.isLoading,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => controller.submit(),
                        autofillHints: [
                          if (viewModel.isRegisterMode) AutofillHints.newPassword else AutofillHints.password,
                        ],
                      ),
                      if (viewModel.infoMessage != null)
                        InfoBar(
                          title: Text(viewModel.infoMessage!),
                          severity: InfoBarSeverity.warning,
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
                                width: 20,
                                height: 20,
                                child: ProgressRing(strokeWidth: 2),
                              )
                            : Text(
                                viewModel.isRegisterMode
                                    ? localizations.loginScreen_createAccountButton
                                    : localizations.loginScreen_signInButton,
                              ),
                      ),
                      if (viewModel.registrationAllowed)
                        Button(
                          onPressed: viewModel.isLoading ? null : controller.toggleMode,
                          child: Text(
                            viewModel.isRegisterMode
                                ? localizations.loginScreen_switchToLogin
                                : localizations.loginScreen_switchToRegister,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ServerChip(
                        serverUrl: controller.serverUrl,
                        onEdit: viewModel.isLoading ? null : () => showServerUrlDialog(
                          context,
                          currentUrl: controller.serverUrl,
                          onSave: controller.setServerUrl,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

}
