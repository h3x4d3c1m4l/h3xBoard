import 'package:h3xboard/env.dart';

class Config {

  // --dart-define=API_URL=... takes precedence (acceptance/production).
  // Falls back to the value from .env read by envied at code-generation time.
  static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: Env.apiUrl);

}
