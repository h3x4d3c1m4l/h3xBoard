import 'package:auto_route/auto_route.dart';
import 'package:h3xboard/app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: InitializationRoute.page, initial: true),
    AutoRoute(page: LoginRoute.page),
    AutoRoute(page: StartRoute.page),
    AutoRoute(page: DashboardRoute.page),
    AutoRoute(page: BoardRoute.page),
  ];

}
