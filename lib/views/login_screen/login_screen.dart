import 'package:auto_route/annotations.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_base.dart';
import 'package:h3xboard/views/login_screen/login_screen_controller.dart';
import 'package:h3xboard/views/login_screen/login_screen_view.dart';
import 'package:h3xboard/views/login_screen/login_screen_view_model.dart';

/// A one-off message the login screen shows on arrival, set by whichever flow
/// sent the user here.
enum LoginNotice {

  /// A password reset just completed. The reset deliberately creates no
  /// session, so the user lands here — and needs telling that it worked, or a
  /// form that simply vanished looks like a failure.
  passwordChanged,

}

@RoutePage()
class LoginScreen extends ScreenBase<LoginScreenViewModel, LoginScreenController, LoginScreenView> {

  final LoginNotice? notice;

  const LoginScreen({super.key, this.notice});

  @override
  LoginScreenController createController({
    required LoginScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return LoginScreenController(notice: notice, viewModel: viewModel, contextAccessor: contextAccessor);
  }

  @override
  LoginScreenView createView({
    required LoginScreenController controller,
    required LoginScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return LoginScreenView(viewModel: viewModel, controller: controller, contextAccessor: contextAccessor);
  }

  @override
  LoginScreenViewModel createViewModel({required BuildContextAccessor contextAccessor}) {
    return LoginScreenViewModel(contextAccessor: contextAccessor);
  }

}
