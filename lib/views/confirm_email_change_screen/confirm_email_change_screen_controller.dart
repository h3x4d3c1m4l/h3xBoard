import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/confirm_email_change_screen/confirm_email_change_screen_view_model.dart';

class ConfirmEmailChangeScreenController extends ScreenControllerBase<ConfirmEmailChangeScreenViewModel> {

  final _auth = GetIt.I<H3xBoardAuthService>();

  /// The single-use token from the confirmation e-mail. Null when this page is
  /// reached without one (a reload, once the token has been stripped).
  final String? token;

  bool _disposed = false;

  ConfirmEmailChangeScreenController({
    required this.token,
    required super.viewModel,
    required super.contextAccessor,
  }) {
    unawaited(confirm());
  }

  Future<void> confirm() async {
    final token = this.token;
    // No token at all is the same story as a spent one, and is told the same way.
    if (token == null || token.isEmpty) {
      viewModel.setStatus(ConfirmEmailChangeStatus.invalidToken);
      return;
    }

    viewModel.setStatus(ConfirmEmailChangeStatus.confirming);
    try {
      final result = await _auth.confirmEmailChange(token);
      viewModel.setConfirmed(result.email);
    } on H3xBoardApiException catch (e) {
      viewModel.setStatus(switch (e.code) {
        400 => ConfirmEmailChangeStatus.invalidToken,
        409 => ConfirmEmailChangeStatus.addressTaken,
        429 => ConfirmEmailChangeStatus.rateLimited,
        _ => ConfirmEmailChangeStatus.failed,
      });
    } catch (_) {
      viewModel.setStatus(ConfirmEmailChangeStatus.failed);
    }
  }

  /// Leaves the screen the way the bootstrap would have: this link is opened in
  /// whatever browser holds the *new* mailbox, which may or may not have a
  /// session, so let [InitializationRoute] find that out and land on the boards
  /// or the login screen accordingly.
  void onContinue() {
    unawaited(_replaceAll([const InitializationRoute()]));
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
