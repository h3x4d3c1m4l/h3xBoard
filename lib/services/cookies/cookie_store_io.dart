import 'package:cookie_jar/cookie_jar.dart';
import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:h3xboard/services/cookies/secure_cookie_storage.dart';

/// IO implementation: a [PersistCookieJar] backed by secure storage does the
/// RFC cookie bookkeeping (domain/path/expiry). We only translate between raw
/// header strings and [Cookie] objects.
class CookieStoreImpl implements CookieStore {

  final PersistCookieJar _jar = PersistCookieJar(storage: SecureCookieStorage());

  @override
  Future<String?> cookieHeader(Uri uri) async {
    final cookies = await _jar.loadForRequest(uri);
    if (cookies.isEmpty) return null;
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }

  @override
  Future<void> saveFromResponse(Uri uri, List<String> setCookieHeaders) async {
    final cookies = <Cookie>[];
    for (final header in setCookieHeaders) {
      try {
        cookies.add(Cookie.fromSetCookieValue(header));
      } catch (_) {
        // Ignore malformed Set-Cookie values rather than failing the request.
      }
    }
    if (cookies.isNotEmpty) await _jar.saveFromResponse(uri, cookies);
  }

  @override
  Future<void> clear() => _jar.deleteAll();

}
