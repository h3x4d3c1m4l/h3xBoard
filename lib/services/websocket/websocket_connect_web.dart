import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Web: the browser attaches the session cookie to the WebSocket handshake
/// automatically, so [cookieStore] is unused and the generic channel is fine.
Future<WebSocketChannel> connectWebSocket(Uri uri, CookieStore cookieStore) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return channel;
}
