import 'package:flutter/foundation.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

enum UnauthReason { none, loggedOut, expired }

/// App-level source of truth for authentication state.
///
/// Extends [ChangeNotifier] so it can be passed to auto_route's
/// `reevaluateListenable`: whenever the status changes the router re-runs all
/// guards, which is how a user is bounced back to the login screen the moment
/// their session is confirmed invalid.
class SessionController extends ChangeNotifier {

  SessionStatus _status = SessionStatus.unknown;
  UnauthReason _reason = UnauthReason.none;
  String? _userId;
  String? _email;

  SessionStatus get status => _status;
  UnauthReason get reason => _reason;
  String? get userId => _userId;
  String? get email => _email;

  bool get isAuthenticated => _status == SessionStatus.authenticated;

  void markAuthenticated(String userId, String email) {
    _userId = userId;
    _email = email;
    _status = SessionStatus.authenticated;
    _reason = UnauthReason.none;
    notifyListeners();
  }

  void markUnauthenticated({UnauthReason reason = UnauthReason.loggedOut}) {
    _userId = null;
    _email = null;
    _status = SessionStatus.unauthenticated;
    _reason = reason;
    notifyListeners();
  }

  /// Clears the [reason] after the login screen has shown the matching message,
  /// so it is not shown again on a later visit.
  void consumeReason() {
    _reason = UnauthReason.none;
  }

}
