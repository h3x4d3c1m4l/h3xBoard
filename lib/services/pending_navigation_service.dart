import 'package:auto_route/auto_route.dart';

/// Holds a single pending [PageRouteInfo] across the app-initialization flow.
///
/// When the auth guard intercepts a protected route while the session is still
/// unknown, it stores the intended destination here before redirecting to
/// [InitializationRoute]. After initialization (or login), callers consume the
/// stored route and navigate there instead of the generic boards screen.
class PendingNavigationService {

  PageRouteInfo? _pendingRoute;

  void setPendingRoute(PageRouteInfo route) {
    _pendingRoute = route;
  }

  PageRouteInfo? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

}
