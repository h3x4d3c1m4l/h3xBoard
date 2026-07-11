import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/auth_response.dart';
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/pending_navigation_service.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/login_screen/login_screen_view_model.dart';

class LoginScreenController extends ScreenControllerBase<LoginScreenViewModel> {

  final _auth = GetIt.I<H3xBoardAuthService>();
  final _wsClient = GetIt.I<H3xBoardApiClient>();
  final _session = GetIt.I<SessionController>();
  final _server = GetIt.I<ServerController>();

  LoginScreenController({
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
    viewModel.setRegistrationAllowed(_server.serverInfo.value?.registrationAllowed ?? true);
  }

  void toggleMode() => viewModel.toggleMode();

  Future<void> submit() async {
    viewModel
      ..setIsLoading(true)
      ..setErrorMessage(null)
      ..setInfoMessage(null);
    try {
      final AuthResponse result = viewModel.isRegisterMode
          ? await _auth.register(
              email: viewModel.emailController.text,
              password: viewModel.passwordController.text,
              firstName: viewModel.firstNameController.text,
              lastName: viewModel.lastNameController.text,
            )
          : await _auth.login(
              email: viewModel.emailController.text,
              password: viewModel.passwordController.text,
            );
      await _wsClient.connect();
      // Credentials were accepted: let the platform/browser offer to save them.
      TextInput.finishAutofillContext();
      _session.markAuthenticated(
        result.userId,
        result.email,
        firstName: result.firstName,
        lastName: result.lastName,
      );
      // Navigate explicitly rather than leaning on the guard's reevaluate
      // redirect, which is unreliable while a deep-link route is still pending.
      if (contextAccessor.buildContext.mounted) {
        final pending = GetIt.I<PendingNavigationService>().consumePendingRoute();
        await contextAccessor.buildContext.router.replaceAll([pending ?? const BoardsRoute()]);
      }
    } on H3xBoardApiException catch (e) {
      viewModel.setErrorMessage(e.message);
    } catch (e) {
      viewModel.setErrorMessage(e.toString());
    } finally {
      viewModel.setIsLoading(false);
    }
  }

  @override
  void dispose() {
    _server.serverInfo.removeListener(_syncFromServerInfo);
    super.dispose();
  }

}
