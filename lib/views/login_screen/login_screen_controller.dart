import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
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
import 'package:h3xboard/views/components/dialogs/watch_code_dialog.dart';
import 'package:h3xboard/views/login_screen/login_screen_view_model.dart';

class LoginScreenController extends ScreenControllerBase<LoginScreenViewModel> {

  /// The names the four fields are registered under in the form, and the keys
  /// their values come back under in [FormBuilderState.value].
  static const emailField = 'email';
  static const passwordField = 'password';
  static const firstNameField = 'firstName';
  static const lastNameField = 'lastName';

  static final FormFieldValidator<String> _emailRule = FormBuilderValidators.compose<String>([
    FormBuilderValidators.required<String>(),
    FormBuilderValidators.email(),
  ]);

  /// What the email field has to be before the form will call the server.
  ///
  /// `required` before `email` so a blank field says it is blank rather than
  /// that it is not an address. Both messages come from
  /// form_builder_validators' own translations, which is why
  /// `FormBuilderLocalizations.delegate` is registered in `board_app.dart`.
  ///
  /// Trimmed before checking, to agree with the field's `valueTransformer`: a
  /// tablet keyboard hands out a trailing space for free, and an address
  /// refused over one is a baffling thing to be told when the form would have
  /// sent the trimmed value anyway.
  static String? emailValidator(String? value) => _emailRule(value?.trim());

  /// The password is only checked for being there. Every rule about *what* a
  /// password may be belongs to the server, which is the only side that knows
  /// them and the only side that can enforce them.
  static final FormFieldValidator<String> passwordValidator = FormBuilderValidators.required<String>();

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

  void toggleMode() {
    viewModel.toggleMode();
    // Back to a blank form: the two fields that survive the switch keep their
    // text (and their errors) otherwise, since they are the same fields.
    viewModel.formKey.currentState?.reset();
  }

  /// Asks for a share code and opens the anonymous board viewer on it (pushed,
  /// so leaving the viewer returns here).
  void onWatchBoard() => unawaited(_promptForCode());

  Future<void> _promptForCode() async {
    final code = await showWatchCodeDialog(contextAccessor.buildContext);
    if (code == null) return;
    final context = contextAccessor.buildContext;
    if (!context.mounted) return;
    unawaited(context.router.push(ViewerRoute(code: code)));
  }

  /// Puts the caret in the first field the form refused, in the order the
  /// fields are built.
  void _focusFirstInvalidField(FormBuilderState form) {
    for (final field in form.fields.values) {
      if (field.hasError) {
        field.focus();
        return;
      }
    }
  }

  Future<void> submit() async {
    final form = viewModel.formKey.currentState;
    if (form == null) return;

    // A refused submit is what arms live validation: from here on the view hands
    // the form an AutovalidateMode, so a field re-checks itself as it is fixed.
    viewModel.enableValidateOnEdit();
    // `focusOnInvalid: false` and the jump done by hand, because the flag is
    // sticky: FormState re-validates every field on every build once the form
    // has been interacted with, and each of those validations would move focus
    // into the first invalid field whenever focus sits outside the form — from
    // a dialog opened over the screen, for instance.
    if (!form.saveAndValidate(focusOnInvalid: false)) {
      _focusFirstInvalidField(form);
      return;
    }

    final values = form.value;
    // Non-null past saveAndValidate: both rules are `required`.
    final email = values[emailField] as String? ?? '';
    final password = values[passwordField] as String? ?? '';

    viewModel
      ..setIsLoading(true)
      ..setErrorMessage(null)
      ..setInfoMessage(null);
    try {
      final AuthResponse result = viewModel.isRegisterMode
          ? await _auth.register(
              email: email,
              password: password,
              firstName: values[firstNameField] as String? ?? '',
              lastName: values[lastNameField] as String? ?? '',
            )
          : await _auth.login(
              email: email,
              password: password,
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
