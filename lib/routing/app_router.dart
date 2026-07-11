import 'package:auto_route/auto_route.dart';
import 'package:h3xboard/routing/app_router.gr.dart';
import 'package:h3xboard/routing/auth_guard.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {

  @override
  List<AutoRouteGuard> get guards => [AuthGuard()];

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: InitializationRoute.page, initial: true, path: '/initialization'),
    AutoRoute(page: LoginRoute.page, path: '/login'),
    AutoRoute(page: BoardsRoute.page, path: '/boards'),
    AutoRoute(page: BoardRoute.page, path: '/board/:boardId'),
  ];

}
