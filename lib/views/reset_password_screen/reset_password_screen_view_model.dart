import 'package:flutter/widgets.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'reset_password_screen_view_model.g.dart';

class ResetPasswordScreenViewModel = ResetPasswordScreenViewModelBase with _$ResetPasswordScreenViewModel;

abstract class ResetPasswordScreenViewModelBase extends ScreenViewModelBase with Store {

  /// The shortest password the server accepts. Checked here as well so a typo
  /// costs a keystroke instead of a round trip — and, more importantly, so the
  /// user is never told "invalid or expired link" for what was only a short
  /// password (the server returns 400 for both).
  static const int minPasswordLength = 8;

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @readonly
  bool _isSubmitting = false;

  @readonly
  String? _errorMessage;

  /// Set when the server rejects the token itself: the form is useless from
  /// here on, so the screen swaps it for a way to request a fresh link.
  @readonly
  bool _isLinkDead = false;

  ResetPasswordScreenViewModelBase({required super.contextAccessor});

  @action
  void setIsSubmitting(bool value) => _isSubmitting = value;

  @action
  void setErrorMessage(String? value) => _errorMessage = value;

  @action
  void markLinkDead() {
    _isLinkDead = true;
    _errorMessage = null;
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

}
