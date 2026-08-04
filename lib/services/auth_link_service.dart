import 'package:h3xboard/models/auth_link.dart';
import 'package:h3xboard/services/auth_link_reader_web.dart'
    if (dart.library.io) 'package:h3xboard/services/auth_link_reader_io.dart';

/// Holds the account-lifecycle link (verify e-mail, reset password, confirm an
/// address change) the app was opened with.
///
/// The link is read — and its token stripped from the address bar — the moment
/// this service is constructed, which is before the router exists. The router's
/// `deepLinkBuilder` then [consume]s it to decide where the app starts, so a
/// mailed link opens its screen instead of the normal bootstrap.
///
/// Registered as a GetIt singleton in `setupServices`.
class AuthLinkService {

  AuthLink? _pendingLink;

  AuthLinkService() : _pendingLink = readLaunchAuthLink();

  /// Whether the app was opened with a link that has not been handled yet.
  bool get hasPendingLink => _pendingLink != null;

  /// Returns the pending link once; every later call returns null, so a
  /// spent token can never be replayed by a rebuild.
  AuthLink? consumePendingLink() {
    final link = _pendingLink;
    _pendingLink = null;
    return link;
  }

}
