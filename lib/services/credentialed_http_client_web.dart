import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart';

/// Web: the browser client with `withCredentials` sends the session cookie on
/// cross-origin API requests. The [cookieStore] is unused here (it is a no-op on
/// web) but kept in the signature so the call site is platform-agnostic.
Client createCredentialedHttpClient(CookieStore cookieStore) => BrowserClient()..withCredentials = true;
