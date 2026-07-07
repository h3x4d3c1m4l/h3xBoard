import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/app_router.dart';
import 'package:h3xboard/app_router.gr.dart';
import 'package:h3xboard/board_app.dart';
import 'package:h3xboard/config.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/services/pending_navigation_service.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/services/server_settings_store.dart';
import 'package:h3xboard/services/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServices();
  runApp(const BoardApp());
}

/// Registers the app-wide singletons before the widget tree is built, so the
/// router can read [SessionController] for `reevaluateListenable` and guards.
Future<void> setupServices() async {
  final session = SessionController();
  // The user-chosen server URL (if any) wins over the compile-time default; it
  // is loaded before the services are created so they point at the right host.
  final serverSettings = ServerSettingsStore();
  final initialUrl = (await serverSettings.getServerUrl()) ?? Config.apiUrl;
  final auth = H3xBoardAuthService.create(initialUrl);
  final files = H3xBoardFileService.create(initialUrl);
  final appRouter = AppRouter();

  // After a dropped socket, ask REST whoami to tell a transient blip apart from
  // a real expiry: true = valid, false = 401 (invalid), null = network/unknown.
  final api = H3xBoardApiClient(serverUrl: initialUrl)
    ..sessionValidator = (() async {
      try {
        return (await auth.whoami()) != null;
      } catch (_) {
        return null;
      }
    })
    ..onSessionExpired = (() {
      session.markUnauthenticated(reason: UnauthReason.expired);
      // Navigate explicitly rather than leaning on the guard's reevaluate
      // redirect, which is unreliable while a deep-link route is still pending.
      unawaited(appRouter.replaceAll([LoginRoute()]));
    });

  final serverController = ServerController(
    initialUrl: initialUrl,
    auth: auth,
    files: files,
    api: api,
    store: serverSettings,
  );

  GetIt.I
    ..registerSingleton<SessionController>(session)
    ..registerSingleton<H3xBoardAuthService>(auth)
    ..registerSingleton<H3xBoardFileService>(files)
    ..registerSingleton<H3xBoardApiClient>(api)
    ..registerSingleton<AppSettingsController>(AppSettingsController(api))
    ..registerSingleton<AppRouter>(appRouter)
    ..registerSingleton<PendingNavigationService>(PendingNavigationService())
    ..registerSingleton<ServerController>(serverController);

  // Prime the server info (warning banner, registration capability) before the
  // first screen renders; it refreshes again on every later disconnect.
  unawaited(serverController.refreshServerInfo());
}
