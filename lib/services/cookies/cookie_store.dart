import 'package:h3xboard/services/cookies/cookie_store_web.dart'
    if (dart.library.io) 'package:h3xboard/services/cookies/cookie_store_io.dart';

/// Cross-platform session-cookie store.
///
/// On web this is a no-op: the browser owns the cookie jar and attaches the
/// session cookie to both HTTP (`withCredentials`) and WebSocket handshakes
/// automatically. On IO (Android/iOS/desktop) there is no browser jar, so the
/// [CookieStore] persists `Set-Cookie` from responses (via cookie_jar backed by
/// flutter_secure_storage) and hands the `Cookie` header back for outgoing REST
/// and WebSocket requests.
///
/// Both the REST client and the WebSocket client share a single instance so the
/// cookie captured at login is available to every subsequent request.
abstract class CookieStore {

  /// Creates the platform-appropriate implementation.
  factory CookieStore() = CookieStoreImpl;

  /// The `Cookie` request-header value for [uri], or null when there is nothing
  /// to send (always null on web — the browser adds it).
  Future<String?> cookieHeader(Uri uri);

  /// Persist the `Set-Cookie` values (raw header strings) returned for [uri].
  /// No-op on web.
  Future<void> saveFromResponse(Uri uri, List<String> setCookieHeaders);

  /// Forget all stored cookies (e.g. on logout). No-op on web.
  Future<void> clear();

}
