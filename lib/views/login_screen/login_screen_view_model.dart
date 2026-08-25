import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'login_screen_view_model.g.dart';

class LoginScreenViewModel = LoginScreenViewModelBase with _$LoginScreenViewModel;

abstract class LoginScreenViewModelBase extends ScreenViewModelBase with Store {

  /// The form itself: field values, per-field errors and validation all live in
  /// [FormBuilderState], which is why there are no observables for them here.
  /// The controller reaches the values through `formKey.currentState`.
  final formKey = GlobalKey<FormBuilderState>();

  @readonly
  bool _isLoading = false;

  @readonly
  String? _errorMessage;

  @readonly
  String? _infoMessage;

  @readonly
  bool _isRegisterMode = false;

  /// Whether the fields re-validate on every keystroke.
  ///
  /// Off until the first submit attempt: flagging a half-typed address while
  /// someone is still typing it is noise, and platform autofill fills both
  /// fields without either passing through a "finished typing" moment. The view
  /// turns this into the form's [AutovalidateMode].
  @readonly
  bool _validateOnEdit = false;

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
  void enableValidateOnEdit() => _validateOnEdit = true;

  /// Switches between sign-in and register. Clearing the fields themselves is
  /// the controller's job — it is the side that can reach the form's state.
  @action
  void toggleMode() {
    _isRegisterMode = !_isRegisterMode;
    _errorMessage = null;
    _infoMessage = null;
    // The form is about to be reset, so the empty one the user is looking at has
    // not been submitted yet.
    _validateOnEdit = false;
  }

}
