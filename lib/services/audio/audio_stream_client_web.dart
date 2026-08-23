import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart';

/// Web: the Fetch API, whose response body is a real `ReadableStream` that can
/// be read while it is still arriving. The [credentialed] client is ignored
/// here. It is a `BrowserClient` built on XMLHttpRequest, which has no
/// incremental read. It hands over the whole body in one event at the end,
/// which would make "streaming" audio an ordinary download with extra steps.
///
/// Dropping it loses nothing. The browser attaches the session cookie itself
/// given [RequestCredentials.cors], which is named after the CORS mode it
/// enables rather than after its wire value, `include`. That matches what
/// `BrowserClient..withCredentials = true` does for the rest of the API.
/// Sending the cookie is harmless on the anonymous share-code endpoint, which
/// authenticates by share code rather than by session.
Client createPlatformAudioStreamClient(Client credentialed) => FetchClient(
      mode: RequestMode.cors,
      credentials: RequestCredentials.cors,
    );
