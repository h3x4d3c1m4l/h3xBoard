import 'package:h3xboard/models/auth_link.dart';

/// Non-web: the account-lifecycle e-mails link to the web app, and the native
/// builds register no URL scheme of their own, so there is never a launch token
/// to read here. Kept API-compatible with the web implementation so callers
/// need no platform checks.
AuthLink? readLaunchAuthLink() => null;
