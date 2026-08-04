import 'package:flutter/widgets.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'login_screen_view_model.g.dart';

class LoginScreenViewModel = LoginScreenViewModelBase with _$LoginScreenViewModel;

abstract class LoginScreenViewModelBase extends ScreenViewModelBase with Store {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  @readonly
  bool _isLoading = false;

  @readonly
  String? _errorMessage;

  @readonly
  String? _infoMessage;

  /// A "that worked" line — currently only shown after a completed password
  /// reset, which lands here rather than in the app.
  @readonly
  String? _successMessage;

  @readonly
  bool _isRegisterMode = false;

  /// Whether the server accepts new registrations. Optimistically `true` until
  /// the unauthenticated `serverInfo` capabilities call says otherwise.
  @readonly
  bool _registrationAllowed = true;

  /// Whether this server withholds the session until the address is confirmed.
  /// Decides where a fresh registration lands: in the app, or in the "check
  /// your inbox" waiting room.
  @readonly
  bool _emailVerificationRequired = false;

  LoginScreenViewModelBase({required super.contextAccessor});

  @action
  void setIsLoading(bool value) => _isLoading = value;

  @action
  void setRegistrationAllowed(bool value) => _registrationAllowed = value;

  @action
  void setEmailVerificationRequired(bool value) => _emailVerificationRequired = value;

  @action
  void setErrorMessage(String? value) => _errorMessage = value;

  @action
  void setInfoMessage(String? value) => _infoMessage = value;

  @action
  void setSuccessMessage(String? value) => _successMessage = value;

  @action
  void toggleMode() {
    _isRegisterMode = !_isRegisterMode;
    _errorMessage = null;
    _infoMessage = null;
    _successMessage = null;
    emailController.clear();
    passwordController.clear();
    firstNameController.clear();
    lastNameController.clear();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

}
