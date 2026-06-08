import 'package:auto_route/auto_route.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/app_router.gr.dart';
import 'package:h3xboard/services/session_controller.dart';

/// Global navigation guard driven by [SessionController].
///
/// - [InitializationRoute] is reachable only during the one-time bootstrap
///   (`status == unknown`); once the status is resolved it redirects away, so
///   the user can never navigate back to it.
/// - [LoginRoute] is hidden from authenticated users (redirected to Start).
/// - Every other (protected) route requires authentication.
class AuthGuard extends AutoRouteGuard {

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final session = GetIt.I<SessionController>();

    switch (resolver.routeName) {
      case InitializationRoute.name:
        if (session.status == SessionStatus.unknown) {
          resolver.next(true);
        } else if (session.isAuthenticated) {
          resolver.redirectUntil(StartRoute());
        } else {
          resolver.redirectUntil(LoginRoute());
        }
      case LoginRoute.name:
        if (session.status == SessionStatus.unknown) {
          // Reloaded straight onto Login before the session was resolved — run
          // the bootstrap first so a still-valid session is restored.
          resolver.redirectUntil(InitializationRoute());
        } else if (session.isAuthenticated) {
          resolver.redirectUntil(StartRoute());
        } else {
          resolver.next(true);
        }
      default:
        if (session.status == SessionStatus.unknown) {
          // Web reload lands directly on a protected route, bypassing the
          // one-time InitializationScreen. Funnel through it so the session is
          // checked (and the socket reconnected) instead of bouncing to Login.
          resolver.redirectUntil(InitializationRoute());
        } else if (session.isAuthenticated) {
          resolver.next(true);
        } else {
          resolver.redirectUntil(LoginRoute());
        }
    }
  }

}
