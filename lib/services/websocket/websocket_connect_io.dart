import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// IO: there is no browser cookie jar, so the session cookie must be sent as a
/// `Cookie` header on the WebSocket handshake. The header value comes from the
/// same [cookieStore] the REST client uses, keyed by the (http) origin so
/// cookie_jar matches the domain/path it saved the cookie under.
Future<WebSocketChannel> connectWebSocket(Uri uri, CookieStore cookieStore) async {
  final cookie = await cookieStore.cookieHeader(_httpEquivalent(uri));
  final channel = IOWebSocketChannel.connect(
    uri,
    headers: cookie == null ? null : {'cookie': cookie},
  );
  await channel.ready;
  return channel;
}

/// cookie_jar stored the session cookie under the REST origin (http/https);
/// map the ws/wss handshake URI back to that scheme so the host/path match.
Uri _httpEquivalent(Uri uri) {
  final scheme = switch (uri.scheme) {
    'wss' => 'https',
    'ws' => 'http',
    final other => other,
  };
  return uri.replace(scheme: scheme);
}
