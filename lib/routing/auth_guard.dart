import 'package:auto_route/auto_route.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/services/pending_navigation_service.dart';
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
          resolver.redirectUntil(BoardsRoute());
        } else {
          resolver.redirectUntil(LoginRoute());
        }
      case LoginRoute.name:
        if (session.status == SessionStatus.unknown) {
          // Reloaded straight onto Login before the session was resolved — run
          // the bootstrap first so a still-valid session is restored.
          resolver.redirectUntil(InitializationRoute());
        } else if (session.isAuthenticated) {
          resolver.redirectUntil(BoardsRoute());
        } else {
          resolver.next(true);
        }
      case ViewerEntryRoute.name:
      case ViewerRoute.name:
        // The live-share viewer is anonymous by design: reachable without a
        // session, without waiting for the bootstrap (a share link must open
        // instantly), and equally available to signed-in users.
        resolver.next(true);
      default:
        if (session.status == SessionStatus.unknown) {
          // Web reload lands directly on a protected route, bypassing the
          // one-time InitializationScreen. Save the intended destination so
          // initialization (or login) can restore it after auth resolves.
          GetIt.I<PendingNavigationService>().setPendingRoute(
            PageRouteInfo(
              resolver.route.name,
              args: resolver.route.args,
              rawPathParams: resolver.route.params.rawMap,
              rawQueryParams: resolver.route.queryParams.rawMap,
            ),
          );
          resolver.redirectUntil(InitializationRoute());
        } else if (session.isAuthenticated) {
          resolver.next(true);
        } else {
          resolver.redirectUntil(LoginRoute());
        }
    }
  }

}
