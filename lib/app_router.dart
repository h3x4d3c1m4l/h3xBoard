import 'package:auto_route/auto_route.dart';
import 'package:h3xboard/app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {

  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: DashboardRoute.page, initial: true),
    AutoRoute(page: BoardRoute.page),
  ];

}
