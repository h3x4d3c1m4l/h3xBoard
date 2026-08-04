import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/app_language_extension.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/auth_response.dart';
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/pending_navigation_service.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/components/dialogs/forgot_password_dialog.dart';
import 'package:h3xboard/views/login_screen/login_screen.dart';
import 'package:h3xboard/views/login_screen/login_screen_view_model.dart';

class LoginScreenController extends ScreenControllerBase<LoginScreenViewModel> {

  final _auth = GetIt.I<H3xBoardAuthService>();
  final _wsClient = GetIt.I<H3xBoardApiClient>();
  final _session = GetIt.I<SessionController>();
  final _server = GetIt.I<ServerController>();
  final _settings = GetIt.I<AppSettingsController>();

  LoginScreenController({
    LoginNotice? notice,
    required super.viewModel,
    required super.contextAccessor,
  }) {
    // If we landed here because the session expired, explain why — then clear
    // the reason so it is not shown again on a later visit.
    if (_session.reason == UnauthReason.expired) {
      viewModel.setInfoMessage(
        contextAccessor.buildContext.localizations.loginScreen_sessionExpired,
      );
      _session.consumeReason();
    }
    if (notice == LoginNotice.passwordChanged) {
      viewModel.setSuccessMessage(
        contextAccessor.buildContext.localizations.loginScreen_passwordChanged,
      );
    }
    // The shared server info (kept fresh on every disconnect) tells us whether
    // sign-ups are open; mirror it into the view model and stay subscribed so a
    // server-URL change re-hides/re-shows the register UI.
    _server.serverInfo.addListener(_syncFromServerInfo);
    _syncFromServerInfo();
    unawaited(_server.refreshServerInfo());
  }

  /// The API base URL the app is currently pointed at (for the "Server" chip).
  String get serverUrl => _server.serverUrl;

  /// Points the app at [url], persists it, refreshes the server info, and then
  /// re-runs the bootstrap: the new server may already have a valid session
  /// cookie, in which case the user should land on their boards instead of
  /// being asked to sign in again.
  Future<void> setServerUrl(String url) async {
    await _server.setServerUrl(url);
    _session.markUnknown();
    if (contextAccessor.buildContext.mounted) {
      await contextAccessor.buildContext.router.replaceAll([InitializationRoute()]);
    }
  }

  void _syncFromServerInfo() {
    final info = _server.serverInfo.value;
    viewModel
      ..setRegistrationAllowed(info?.registrationAllowed ?? true)
      ..setEmailVerificationRequired(info?.emailVerificationRequired ?? false);
  }

  void toggleMode() => viewModel.toggleMode();

  /// Opens the "send me a reset link" dialog, seeded with whatever address the
  /// user has already typed.
  void onForgotPassword() {
    unawaited(showForgotPasswordDialog(
      contextAccessor.buildContext,
      initialEmail: viewModel.emailController.text.trim(),
    ));
  }

  /// Opens the anonymous board viewer (pushed, so back returns here).
  void onWatchBoard() {
    unawaited(contextAccessor.buildContext.router.push(const ViewerEntryRoute()));
  }

  Future<void> submit() async {
    viewModel
      ..setIsLoading(true)
      ..setErrorMessage(null)
      ..setInfoMessage(null)
      ..setSuccessMessage(null);
    final email = viewModel.emailController.text;
    try {
      final AuthResponse result = viewModel.isRegisterMode
          ? await _auth.register(
              email: email,
              password: viewModel.passwordController.text,
              firstName: viewModel.firstNameController.text,
              lastName: viewModel.lastNameController.text,
              // Sent explicitly so the verification mail arrives in the language
              // the user actually picked; left to Accept-Language it would only
              // ever be a guess among the languages the server happens to ship.
              locale: _settings.language.displayLocaleTag,
            )
          : await _auth.login(
              email: email,
              password: viewModel.passwordController.text,
            );

      // On a server that requires verification, registration deliberately hands
      // back no session — there is nothing to connect the socket with yet, so
      // the account waits in the "check your inbox" room. The account itself
      // does exist, so the browser is still offered the credentials to save.
      if (viewModel.isRegisterMode && viewModel.emailVerificationRequired) {
        TextInput.finishAutofillContext();
        await _goToUnverified(result.email);
        return;
      }

      await _wsClient.connect();
      // Credentials were accepted: let the platform/browser offer to save them.
      TextInput.finishAutofillContext();
      _session.markAuthenticated(
        result.userId,
        result.email,
        firstName: result.firstName,
        lastName: result.lastName,
        emailVerified: result.emailVerified,
      );
      // Navigate explicitly rather than leaning on the guard's reevaluate
      // redirect, which is unreliable while a deep-link route is still pending.
      if (contextAccessor.buildContext.mounted) {
        final pending = GetIt.I<PendingNavigationService>().consumePendingRoute();
        await contextAccessor.buildContext.router.replaceAll([pending ?? const BoardsRoute()]);
      }
    } on H3xBoardApiException catch (e) {
      // Sign-in has exactly one 403 — an address that has not been confirmed —
      // so the status alone identifies it. The password was right, which is why
      // this is a detour rather than an error.
      if (!viewModel.isRegisterMode && e.code == 403) {
        await _goToUnverified(email);
        return;
      }
      viewModel.setErrorMessage(e.message);
    } catch (e) {
      viewModel.setErrorMessage(e.toString());
    } finally {
      viewModel.setIsLoading(false);
    }
  }

  Future<void> _goToUnverified(String email) async {
    if (!contextAccessor.buildContext.mounted) return;
    await contextAccessor.buildContext.router.replaceAll([UnverifiedRoute(email: email)]);
  }

  @override
  void dispose() {
    _server.serverInfo.removeListener(_syncFromServerInfo);
    super.dispose();
  }

}
