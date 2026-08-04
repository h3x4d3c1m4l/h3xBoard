import 'package:auto_route/annotations.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_base.dart';
import 'package:h3xboard/views/verify_email_screen/verify_email_screen_controller.dart';
import 'package:h3xboard/views/verify_email_screen/verify_email_screen_view.dart';
import 'package:h3xboard/views/verify_email_screen/verify_email_screen_view_model.dart';

/// Lands the `/verify-email` link from the registration e-mail: posts its token
/// back and, on success, drops the now signed-in user into the app.
///
/// [token] is deliberately a plain argument rather than a `@QueryParam` — it is
/// a single-use credential, and a query parameter would put it right back in
/// the address bar that `AuthLinkService` just cleaned. It is nullable for the
/// same reason: with the token gone from the URL, reloading this page (or
/// typing its path) arrives without one, and that is a dead link rather than a
/// crash.
@RoutePage()
class VerifyEmailScreen extends ScreenBase<VerifyEmailScreenViewModel, VerifyEmailScreenController, VerifyEmailScreenView> {

  final String? token;

  const VerifyEmailScreen({super.key, this.token});

  @override
  VerifyEmailScreenController createController({
    required VerifyEmailScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return VerifyEmailScreenController(token: token, viewModel: viewModel, contextAccessor: contextAccessor);
  }

  @override
  VerifyEmailScreenView createView({
    required VerifyEmailScreenController controller,
    required VerifyEmailScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return VerifyEmailScreenView(viewModel: viewModel, controller: controller, contextAccessor: contextAccessor);
  }

  @override
  VerifyEmailScreenViewModel createViewModel({required BuildContextAccessor contextAccessor}) {
    return VerifyEmailScreenViewModel(contextAccessor: contextAccessor);
  }

}
