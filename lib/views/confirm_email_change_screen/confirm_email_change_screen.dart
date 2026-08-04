import 'package:auto_route/annotations.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_base.dart';
import 'package:h3xboard/views/confirm_email_change_screen/confirm_email_change_screen_controller.dart';
import 'package:h3xboard/views/confirm_email_change_screen/confirm_email_change_screen_view.dart';
import 'package:h3xboard/views/confirm_email_change_screen/confirm_email_change_screen_view_model.dart';

/// Lands the `/confirm-email-change` link, which is mailed to the *new* address
/// and may well be opened in a browser that has never seen this server — hence
/// no session is assumed, or required.
///
/// [token] is a plain argument rather than a `@QueryParam` — it is a single-use
/// credential, and a query parameter would put it back in the address bar that
/// `AuthLinkService` just cleaned. It is nullable for the same reason: with the
/// token gone from the URL, reloading this page arrives without one, and that
/// is a dead link rather than a crash.
@RoutePage()
class ConfirmEmailChangeScreen
    extends
        ScreenBase<
          ConfirmEmailChangeScreenViewModel,
          ConfirmEmailChangeScreenController,
          ConfirmEmailChangeScreenView
        > {

  final String? token;

  const ConfirmEmailChangeScreen({super.key, this.token});

  @override
  ConfirmEmailChangeScreenController createController({
    required ConfirmEmailChangeScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return ConfirmEmailChangeScreenController(
      token: token,
      viewModel: viewModel,
      contextAccessor: contextAccessor,
    );
  }

  @override
  ConfirmEmailChangeScreenView createView({
    required ConfirmEmailChangeScreenController controller,
    required ConfirmEmailChangeScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return ConfirmEmailChangeScreenView(
      viewModel: viewModel,
      controller: controller,
      contextAccessor: contextAccessor,
    );
  }

  @override
  ConfirmEmailChangeScreenViewModel createViewModel({required BuildContextAccessor contextAccessor}) {
    return ConfirmEmailChangeScreenViewModel(contextAccessor: contextAccessor);
  }

}
