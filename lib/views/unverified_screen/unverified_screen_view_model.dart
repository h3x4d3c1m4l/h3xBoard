import 'package:flutter/widgets.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'unverified_screen_view_model.g.dart';

class UnverifiedScreenViewModel = UnverifiedScreenViewModelBase with _$UnverifiedScreenViewModel;

abstract class UnverifiedScreenViewModelBase extends ScreenViewModelBase with Store {

  /// Only used when the address is unknown — arriving here from a dead
  /// verification link, the token tells us nothing about who owns it.
  final emailController = TextEditingController();

  /// The address the verification mail went to, when we know it (straight from
  /// registration, or from the sign-in attempt that was turned away).
  @readonly
  String? _email;

  @readonly
  bool _isSending = false;

  /// Set once a resend has been asked for. The server answers identically for
  /// every address, so this is a "we've done what we can" acknowledgement, not
  /// a delivery confirmation.
  @readonly
  bool _hasRequestedResend = false;

  @readonly
  String? _errorMessage;

  UnverifiedScreenViewModelBase({required super.contextAccessor, String? email}) : _email = email {
    if (email != null) emailController.text = email;
  }

  @action
  void setIsSending(bool value) => _isSending = value;

  @action
  void setErrorMessage(String? value) => _errorMessage = value;

  @action
  void markResendRequested() {
    _hasRequestedResend = true;
    _errorMessage = null;
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

}
