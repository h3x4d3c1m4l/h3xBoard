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
    AutoRoute(page: ViewerEntryRoute.page, path: '/view'),
    AutoRoute(page: ViewerRoute.page, path: '/view/:code'),
    // The account-lifecycle screens. Their paths match the links the server
    // mails out, but the token never travels as a query parameter: it is read
    // (and stripped) by AuthLinkService before the router runs, and handed to
    // the screen as a plain argument so it cannot leak back into the URL.
    AutoRoute(page: VerifyEmailRoute.page, path: '/verify-email'),
    AutoRoute(page: ResetPasswordRoute.page, path: '/reset-password'),
    AutoRoute(page: ConfirmEmailChangeRoute.page, path: '/confirm-email-change'),
    AutoRoute(page: UnverifiedRoute.page, path: '/unverified'),
  ];

}
