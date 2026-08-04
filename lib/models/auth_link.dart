/// The account-lifecycle links the server mails out. Each one lands on the app
/// with a single-use `?token=` that the client posts back; see
/// `AuthLinkService` for how the token is read (and immediately stripped from
/// the address bar).
enum AuthLinkAction {

  /// `/verify-email` — confirms a registration and signs the user in.
  verifyEmail('/verify-email'),

  /// `/reset-password` — opens the "choose a new password" form.
  resetPassword('/reset-password'),

  /// `/confirm-email-change` — completes an address change.
  confirmEmailChange('/confirm-email-change');

  const AuthLinkAction(this.path);

  /// The path the server puts in the e-mail (`{webAppUrl}{path}?token=…`).
  final String path;

  /// Matches [path] against a URL path, ignoring any prefix the app happens to
  /// be hosted under (`/app/verify-email` is still a verification link).
  static AuthLinkAction? fromPath(String urlPath) {
    final normalized = urlPath.endsWith('/') && urlPath.length > 1
        ? urlPath.substring(0, urlPath.length - 1)
        : urlPath;
    for (final action in values) {
      if (normalized == action.path || normalized.endsWith(action.path)) return action;
    }
    return null;
  }

}

/// One opened link: what it wants done, and the token proving the user reached
/// the mailbox it was sent to.
class AuthLink {

  final AuthLinkAction action;
  final String token;

  const AuthLink({required this.action, required this.token});

}
