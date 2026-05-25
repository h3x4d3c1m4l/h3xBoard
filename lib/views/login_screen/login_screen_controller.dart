import 'package:auto_route/auto_route.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/app_router.gr.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/login_screen/login_screen_view_model.dart';

class LoginScreenController extends ScreenControllerBase<LoginScreenViewModel> {

  final _client = GetIt.I<H3xBoardApiClient>();

  LoginScreenController({
    required super.viewModel,
    required super.contextAccessor,
  });

  void toggleMode() => viewModel.toggleMode();

  Future<void> submit() async {
    final router = contextAccessor.buildContext.router;
    viewModel
      ..setIsLoading(true)
      ..setErrorMessage(null);
    try {
      if (viewModel.isRegisterMode) {
        await _client.register(
          email: viewModel.emailController.text,
          password: viewModel.passwordController.text,
        );
      } else {
        await _client.login(
          email: viewModel.emailController.text,
          password: viewModel.passwordController.text,
        );
      }
      await router.replace(StartRoute());
    } on H3xBoardApiException catch (e) {
      viewModel.setErrorMessage(e.message);
    } catch (e) {
      viewModel.setErrorMessage(e.toString());
    } finally {
      viewModel.setIsLoading(false);
    }
  }

}
