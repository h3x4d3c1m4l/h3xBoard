import 'package:flutter/widgets.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'login_screen_view_model.g.dart';

class LoginScreenViewModel = LoginScreenViewModelBase with _$LoginScreenViewModel;

abstract class LoginScreenViewModelBase extends ScreenViewModelBase with Store {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @readonly
  bool _isLoading = false;

  @readonly
  String? _errorMessage;

  @readonly
  String? _infoMessage;

  @readonly
  bool _isRegisterMode = false;

  /// Whether the server accepts new registrations. Optimistically `true` until
  /// the unauthenticated `serverInfo` capabilities call says otherwise.
  @readonly
  bool _registrationAllowed = true;

  LoginScreenViewModelBase({required super.contextAccessor});

  @action
  void setIsLoading(bool value) => _isLoading = value;

  @action
  void setRegistrationAllowed(bool value) => _registrationAllowed = value;

  @action
  void setErrorMessage(String? value) => _errorMessage = value;

  @action
  void setInfoMessage(String? value) => _infoMessage = value;

  @action
  void toggleMode() {
    _isRegisterMode = !_isRegisterMode;
    _errorMessage = null;
    _infoMessage = null;
    emailController.clear();
    passwordController.clear();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

}
