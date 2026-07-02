import 'package:h3xboard/services/cookies/cookie_store.dart';

/// Web no-op: the browser manages the session cookie for both HTTP and
/// WebSocket requests, so there is nothing for us to store or attach.
class CookieStoreImpl implements CookieStore {

  @override
  Future<String?> cookieHeader(Uri uri) async => null;

  @override
  Future<void> saveFromResponse(Uri uri, List<String> setCookieHeaders) async {}

  @override
  Future<void> clear() async {}

}
