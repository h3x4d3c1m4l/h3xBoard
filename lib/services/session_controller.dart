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
  String? _firstName;
  String? _lastName;

  SessionStatus get status => _status;
  UnauthReason get reason => _reason;
  String? get userId => _userId;
  String? get email => _email;
  String? get firstName => _firstName;
  String? get lastName => _lastName;

  bool get isAuthenticated => _status == SessionStatus.authenticated;

  void markAuthenticated(String userId, String email, {String? firstName, String? lastName}) {
    _userId = userId;
    _email = email;
    _firstName = firstName;
    _lastName = lastName;
    _status = SessionStatus.authenticated;
    _reason = UnauthReason.none;
    notifyListeners();
  }

  void markUnauthenticated({UnauthReason reason = UnauthReason.loggedOut}) {
    _userId = null;
    _email = null;
    _firstName = null;
    _lastName = null;
    _status = SessionStatus.unauthenticated;
    _reason = reason;
    notifyListeners();
  }

  /// Resets the session to [SessionStatus.unknown] so the bootstrap
  /// (InitializationScreen) is allowed to run again. Used after switching
  /// servers: the new host may already have a valid session cookie, so the
  /// "checking session" step has to be redone before deciding where to land.
  void markUnknown() {
    _userId = null;
    _email = null;
    _firstName = null;
    _lastName = null;
    _status = SessionStatus.unknown;
    _reason = UnauthReason.none;
    notifyListeners();
  }

  /// Clears the [reason] after the login screen has shown the matching message,
  /// so it is not shown again on a later visit.
  void consumeReason() {
    _reason = UnauthReason.none;
  }

}
