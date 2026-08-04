import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'confirm_email_change_screen_view_model.g.dart';

/// How far the one-shot confirmation got.
enum ConfirmEmailChangeStatus {

  /// The token is being posted back to the server.
  confirming,

  /// The address moved; [ConfirmEmailChangeScreenViewModelBase.email] holds it.
  confirmed,

  /// The server rejected the token (400) — used already, or older than the
  /// 24 hours a confirmation link lives.
  invalidToken,

  /// Another account claimed the address while this link sat in the inbox (409).
  addressTaken,

  /// Too many token submissions from this address (429).
  rateLimited,

  /// Anything else: no network, server trouble. Worth retrying as-is.
  failed,

}

class ConfirmEmailChangeScreenViewModel = ConfirmEmailChangeScreenViewModelBase
    with _$ConfirmEmailChangeScreenViewModel;

abstract class ConfirmEmailChangeScreenViewModelBase extends ScreenViewModelBase with Store {

  @readonly
  ConfirmEmailChangeStatus _status = ConfirmEmailChangeStatus.confirming;

  /// The account's new address, known only once the server confirms the change.
  @readonly
  String? _email;

  ConfirmEmailChangeScreenViewModelBase({required super.contextAccessor});

  @action
  void setStatus(ConfirmEmailChangeStatus value) => _status = value;

  @action
  void setConfirmed(String email) {
    _email = email;
    _status = ConfirmEmailChangeStatus.confirmed;
  }

}
