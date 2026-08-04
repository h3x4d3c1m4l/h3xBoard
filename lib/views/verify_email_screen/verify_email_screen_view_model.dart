import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'verify_email_screen_view_model.g.dart';

/// How far the one-shot confirmation got. There is no `success` state: a
/// confirmed address signs the user in, so the screen hands over to the
/// bootstrap and is gone before it could render one.
enum VerifyEmailStatus {

  /// The token is being posted back to the server.
  verifying,

  /// The server rejected the token (400) — used once already, or older than the
  /// 24 hours a verification link lives.
  invalidToken,

  /// Too many token submissions from this address (429).
  rateLimited,

  /// Anything else: no network, server trouble. Worth retrying as-is.
  failed,

}

class VerifyEmailScreenViewModel = VerifyEmailScreenViewModelBase with _$VerifyEmailScreenViewModel;

abstract class VerifyEmailScreenViewModelBase extends ScreenViewModelBase with Store {

  @readonly
  VerifyEmailStatus _status = VerifyEmailStatus.verifying;

  VerifyEmailScreenViewModelBase({required super.contextAccessor});

  @action
  void setStatus(VerifyEmailStatus value) => _status = value;

}
