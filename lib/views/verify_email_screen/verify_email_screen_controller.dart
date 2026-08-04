import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/verify_email_screen/verify_email_screen_view_model.dart';

class VerifyEmailScreenController extends ScreenControllerBase<VerifyEmailScreenViewModel> {

  final _auth = GetIt.I<H3xBoardAuthService>();

  /// The single-use token from the verification e-mail. Already stripped from
  /// the address bar by `AuthLinkService` before this screen was built — which
  /// is why it can be null here: a reload of this page arrives without one.
  final String? token;

  bool _disposed = false;

  VerifyEmailScreenController({
    required this.token,
    required super.viewModel,
    required super.contextAccessor,
  }) {
    unawaited(verify());
  }

  /// Posts the token back and, on success, hands over to the bootstrap.
  ///
  /// A confirmed address comes with a session cookie, so there is nothing left
  /// to sign in with — [InitializationRoute] picks that session up, opens the
  /// socket, loads the user's settings and lands on their boards, exactly as it
  /// does on a normal app start.
  Future<void> verify() async {
    final token = this.token;
    // No token at all is the same story as a spent one, and is told the same
    // way: the link cannot work, here is how to get a new one.
    if (token == null || token.isEmpty) {
      viewModel.setStatus(VerifyEmailStatus.invalidToken);
      return;
    }

    viewModel.setStatus(VerifyEmailStatus.verifying);
    try {
      await _auth.verifyEmail(token);
      await _replaceAll([const InitializationRoute()]);
    } on H3xBoardApiException catch (e) {
      viewModel.setStatus(switch (e.code) {
        400 => VerifyEmailStatus.invalidToken,
        429 => VerifyEmailStatus.rateLimited,
        _ => VerifyEmailStatus.failed,
      });
    } catch (_) {
      viewModel.setStatus(VerifyEmailStatus.failed);
    }
  }

  /// Sends the user off to ask for a fresh link. The address is unknown here —
  /// the token is opaque — so the unverified screen asks for it.
  void onRequestNewLink() {
    unawaited(_replaceAll([UnverifiedRoute()]));
  }

  void onBackToSignIn() {
    unawaited(_replaceAll([LoginRoute()]));
  }

  /// Resets the navigation stack to [routes], unless the screen is already gone.
  /// Guarded on [_disposed] first: [BuildContextAccessor.buildContext] is only
  /// assigned once the screen has built, so it must not be touched before then.
  Future<void> _replaceAll(List<PageRouteInfo<dynamic>> routes) async {
    if (_disposed || !contextAccessor.buildContext.mounted) return;
    await contextAccessor.buildContext.router.replaceAll(routes);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

}
