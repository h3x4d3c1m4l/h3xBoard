import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:http/http.dart';

/// Non-web: no browser cookie jar, so wrap the default client to attach the
/// stored session `Cookie` on the way out and persist `Set-Cookie` on the way
/// back. The [cookieStore] is shared with the WebSocket client so both speak to
/// the same session.
Client createCredentialedHttpClient(CookieStore cookieStore) => _CookieClient(Client(), cookieStore);

class _CookieClient extends BaseClient {

  final Client _inner;
  final CookieStore _cookieStore;

  _CookieClient(this._inner, this._cookieStore);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final cookie = await _cookieStore.cookieHeader(request.url);
    if (cookie != null) request.headers['cookie'] = cookie;

    final response = await _inner.send(request);

    // package:http folds multiple Set-Cookie headers into one comma-joined
    // value; split on the comma that precedes a new "name=" pair so each cookie
    // is parsed independently.
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      await _cookieStore.saveFromResponse(request.url, _splitSetCookie(setCookie));
    }
    return response;
  }

  @override
  void close() => _inner.close();

  static List<String> _splitSetCookie(String value) {
    // Split only on commas that start a new cookie (followed by `token=`),
    // leaving intact the commas inside `Expires=Wed, 09 Jun 2021 ...`.
    return value.split(RegExp(r',(?=\s*[^;,\s]+=)')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

}
