import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/components/dialogs/forgot_password_dialog.dart';
import 'package:h3xboard/views/login_screen/login_screen.dart';
import 'package:h3xboard/views/reset_password_screen/reset_password_screen_view_model.dart';

class ResetPasswordScreenController extends ScreenControllerBase<ResetPasswordScreenViewModel> {

  final _auth = GetIt.I<H3xBoardAuthService>();

  /// The single-use token from the password-reset e-mail. Null when this page
  /// is reached without one (a reload, once the token has been stripped).
  final String? token;

  ResetPasswordScreenController({
    required this.token,
    required super.viewModel,
    required super.contextAccessor,
  }) {
    // Nothing to reset with, so skip the form entirely and offer a fresh link
    // rather than letting the user type a password that cannot be saved.
    if (token == null || token!.isEmpty) viewModel.markLinkDead();
  }

  /// Validates the new password locally, then sets it.
  ///
  /// A reset creates no session, so success ends on the login screen — with a
  /// notice, because a form that simply vanishes leaves the user wondering
  /// whether anything happened.
  Future<void> submit() async {
    final token = this.token;
    if (token == null || token.isEmpty) {
      viewModel.markLinkDead();
      return;
    }

    final password = viewModel.passwordController.text;
    final confirmation = viewModel.confirmPasswordController.text;
    if (password.length < ResetPasswordScreenViewModelBase.minPasswordLength) {
      viewModel.setErrorMessage(localizations.resetPasswordScreen_tooShort);
      return;
    }
    if (password != confirmation) {
      viewModel.setErrorMessage(localizations.resetPasswordScreen_mismatch);
      return;
    }

    viewModel
      ..setIsSubmitting(true)
      ..setErrorMessage(null);
    try {
      await _auth.resetPassword(token: token, newPassword: password);
      if (contextAccessor.buildContext.mounted) {
        await contextAccessor.buildContext.router.replaceAll([
          LoginRoute(notice: LoginNotice.passwordChanged),
        ]);
      }
    } on H3xBoardApiException catch (e) {
      switch (e.code) {
        // The password was already checked against the server's own minimum, so
        // a 400 here can only be the token.
        case 400:
          viewModel.markLinkDead();
        case 429:
          viewModel.setErrorMessage(localizations.resetPasswordScreen_rateLimited);
        default:
          viewModel.setErrorMessage(localizations.resetPasswordScreen_failed);
      }
    } catch (_) {
      viewModel.setErrorMessage(localizations.resetPasswordScreen_failed);
    } finally {
      viewModel.setIsSubmitting(false);
    }
  }

  /// Asks for a fresh reset link without leaving the screen.
  void onRequestNewLink() {
    unawaited(showForgotPasswordDialog(contextAccessor.buildContext));
  }

  void onBackToSignIn() {
    unawaited(contextAccessor.buildContext.router.replaceAll([LoginRoute()]));
  }

}
