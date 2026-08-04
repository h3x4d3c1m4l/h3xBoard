import 'package:auto_route/annotations.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_base.dart';
import 'package:h3xboard/views/reset_password_screen/reset_password_screen_controller.dart';
import 'package:h3xboard/views/reset_password_screen/reset_password_screen_view.dart';
import 'package:h3xboard/views/reset_password_screen/reset_password_screen_view_model.dart';

/// Lands the `/reset-password` link from the "forgot your password" e-mail:
/// asks for a new password and sets it with the link's token.
///
/// [token] is a plain argument rather than a `@QueryParam` — it is a single-use
/// credential, and a query parameter would put it back in the address bar that
/// `AuthLinkService` just cleaned. It is nullable for the same reason: with the
/// token gone from the URL, reloading this page arrives without one, and that
/// is a dead link rather than a crash.
@RoutePage()
class ResetPasswordScreen extends ScreenBase<ResetPasswordScreenViewModel, ResetPasswordScreenController, ResetPasswordScreenView> {

  final String? token;

  const ResetPasswordScreen({super.key, this.token});

  @override
  ResetPasswordScreenController createController({
    required ResetPasswordScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return ResetPasswordScreenController(token: token, viewModel: viewModel, contextAccessor: contextAccessor);
  }

  @override
  ResetPasswordScreenView createView({
    required ResetPasswordScreenController controller,
    required ResetPasswordScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return ResetPasswordScreenView(viewModel: viewModel, controller: controller, contextAccessor: contextAccessor);
  }

  @override
  ResetPasswordScreenViewModel createViewModel({required BuildContextAccessor contextAccessor}) {
    return ResetPasswordScreenViewModel(contextAccessor: contextAccessor);
  }

}
