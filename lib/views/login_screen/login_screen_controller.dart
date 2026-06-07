import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/auth_response.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/session_controller.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/login_screen/login_screen_view_model.dart';

class LoginScreenController extends ScreenControllerBase<LoginScreenViewModel> {

  final _auth = GetIt.I<H3xBoardAuthService>();
  final _wsClient = GetIt.I<H3xBoardApiClient>();
  final _session = GetIt.I<SessionController>();

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
            )
          : await _auth.login(
              email: viewModel.emailController.text,
              password: viewModel.passwordController.text,
            );
      await _wsClient.connect();
      // Flipping the status drives navigation: the guard redirects Login → Start.
      _session.markAuthenticated(result.userId, result.email);
    } on H3xBoardApiException catch (e) {
      viewModel.setErrorMessage(e.message);
    } catch (e) {
      viewModel.setErrorMessage(e.toString());
    } finally {
      viewModel.setIsLoading(false);
    }
  }

}
