import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/api/server_info.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/login_screen/login_screen_controller.dart';
import 'package:h3xboard/views/login_screen/login_screen_view_model.dart';
import 'package:h3xboard/widgets/continuous_text_box.dart';
import 'package:h3xboard/widgets/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
                      _ServerChip(
                        serverUrl: controller.serverUrl,
                        enabled: !viewModel.isLoading,
                        onEdit: () => _showServerUrlDialog(context, controller),
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

/// A subtle, tappable chip at the bottom of the login form showing which server
/// the app is connected to and opening the "change server URL" dialog.
class _ServerChip extends StatelessWidget {

  final String serverUrl;
  final bool enabled;
  final VoidCallback onEdit;

  const _ServerChip({
    required this.serverUrl,
    required this.enabled,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final host = _hostOf(serverUrl);
    return Align(
      child: HyperlinkButton(
        onPressed: enabled ? onEdit : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.server, size: 14, color: theme.resources.textFillColorSecondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.localizations.loginScreen_serverLabel(host),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Strips the scheme so the chip reads as a compact host (falls back to the
  /// full string when it can't be parsed).
  static String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

}

/// Prompts for a new server URL, pre-filled with the current one, and applies it
/// via the controller (which re-points the services and refreshes server info).
void _showServerUrlDialog(BuildContext context, LoginScreenController controller) {
  final loc = context.localizations;
  final textController = TextEditingController(text: controller.serverUrl);

  showDialog<void>(
    context: context,
    builder: (ctx) => ThemableContentDialog(
      title: Text(loc.serverUrlDialog_title),
      constraints: const BoxConstraints(maxWidth: 460),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(loc.serverUrlDialog_subtitle),
          const SizedBox(height: 12),
          ContinuousTextBox(
            controller: textController,
            placeholder: loc.serverUrlDialog_placeholder,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _applyAndClose(ctx, controller, textController.text),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(loc.serverUrlDialog_cancel),
        ),
        FilledButton(
          onPressed: () => _applyAndClose(ctx, controller, textController.text),
          child: Text(loc.serverUrlDialog_save),
        ),
      ],
    ),
  );
}

void _applyAndClose(BuildContext ctx, LoginScreenController controller, String url) {
  final trimmed = url.trim();
  if (trimmed.isNotEmpty) controller.setServerUrl(trimmed);
  Navigator.of(ctx).pop();
}
