import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/unverified_screen/unverified_screen_view_model.dart';

class UnverifiedScreenController extends ScreenControllerBase<UnverifiedScreenViewModel> {

  final _auth = GetIt.I<H3xBoardAuthService>();

  UnverifiedScreenController({
    required super.viewModel,
    required super.contextAccessor,
  });

  /// Asks for a fresh verification e-mail.
  ///
  /// The server returns `202` for a known address, an unknown one and an
  /// already-verified one alike, so success here means only "we asked". Saying
  /// anything more specific would leak whether the account exists.
  Future<void> resendVerification() async {
    final email = viewModel.emailController.text.trim();
    if (email.isEmpty) return;

    viewModel
      ..setIsSending(true)
      ..setErrorMessage(null);
    try {
      await _auth.resendVerification(email);
      viewModel.markResendRequested();
    } on H3xBoardApiException catch (e) {
      viewModel.setErrorMessage(e.code == 429
          ? localizations.unverifiedScreen_rateLimited
          : localizations.unverifiedScreen_failed);
    } catch (_) {
      viewModel.setErrorMessage(localizations.unverifiedScreen_failed);
    } finally {
      viewModel.setIsSending(false);
    }
  }

  void onBackToSignIn() {
    unawaited(contextAccessor.buildContext.router.replaceAll([LoginRoute()]));
  }

}
