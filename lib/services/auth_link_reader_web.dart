import 'package:h3xboard/models/auth_link.dart';
import 'package:web/web.dart' as web;

/// Web: reads the account-lifecycle link the tab was opened with and **removes
/// the token from the address bar before returning**.
///
/// Both shapes the token can arrive in are accepted: the path the server mails
/// (`https://app/verify-email?token=…`, served by the SPA fallback) and the
/// hash form the app's own router produces (`https://app/#/verify-email?token=…`).
///
/// The token is a single-use credential, so it must not linger: browser history
/// keeps it, and it would ride along in the `Referer` of every later request.
/// Flutter's hash URL strategy makes that worse — it carries the current query
/// string into every URL it pushes, so an unstripped token would survive the
/// whole session. Stripping is a `history.replaceState` back to the app's base
/// URL, keeping the engine's own history state object so Flutter's history
/// bookkeeping stays intact.
AuthLink? readLaunchAuthLink() {
  final uri = Uri.base;
  final link = _linkIn(uri) ?? _linkIn(Uri.tryParse(uri.fragment));
  if (link == null) return null;
  _stripUrl();
  return link;
}

AuthLink? _linkIn(Uri? uri) {
  if (uri == null) return null;
  final action = AuthLinkAction.fromPath(uri.path);
  if (action == null) return null;
  final token = uri.queryParameters['token'];
  if (token == null || token.isEmpty) return null;
  return AuthLink(action: action, token: token);
}

/// Rewrites the address bar to the app's base URL — no query, no fragment — so
/// a reload re-enters the app cleanly rather than replaying a spent token.
void _stripUrl() {
  web.window.history.replaceState(web.window.history.state, '', web.document.baseURI);
}
