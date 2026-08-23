import 'package:http/http.dart';

/// Non-web: `package:http`'s default client already reads the response body
/// incrementally. So the [credentialed] client the app already uses *is* the
/// streaming client — it streams and it carries the session cookie.
Client createPlatformAudioStreamClient(Client credentialed) => credentialed;
