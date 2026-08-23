import 'package:h3xboard/services/audio/audio_stream_client_web.dart'
    if (dart.library.io) 'package:h3xboard/services/audio/audio_stream_client_io.dart';
import 'package:http/http.dart';

/// A client whose `send()` yields a **genuinely progressive** response body.
///
/// This exists because `package:http` only streams on some platforms. Its
/// `BrowserClient` is built on XMLHttpRequest, which has no incremental read.
/// `send()` returns a `StreamedResponse` whose stream emits the whole body in
/// one event once the transfer finishes. Everything else in the app reads the
/// full body anyway and never noticed. Audio streaming is the first thing that
/// notices, and on web the viewer *is* the browser, so web is exactly the
/// platform that must work.
///
/// The web implementation is built on the Fetch API instead, whose response body
/// is a real `ReadableStream`. This factory is kept separate from
/// [createCredentialedHttpClient] rather than replacing it. Swapping the client
/// underneath every existing REST and chopper call would buy streaming for one
/// widget and nothing for any of those calls. That is a large blast radius for
/// no benefit.
///
/// [credentialed] is the client the rest of the app uses. Non-web returns it
/// unchanged — it already streams — while web replaces it with a Fetch-based one
/// and relies on the browser for cookies. Callers that need no session (the
/// anonymous share-code endpoint) can pass a plain [Client].
Client createAudioStreamClient(Client credentialed) => createPlatformAudioStreamClient(credentialed);
