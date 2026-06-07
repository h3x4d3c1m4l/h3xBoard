import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/board_app.dart';
import 'package:h3xboard/config.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/services/session_controller.dart';

void main() {
  setupServices();
  runApp(const BoardApp());
}

/// Registers the app-wide singletons before the widget tree is built, so the
/// router can read [SessionController] for `reevaluateListenable` and guards.
void setupServices() {
  final session = SessionController();
  final auth = H3xBoardAuthService.create(Config.apiUrl);

  // After a dropped socket, ask REST whoami to tell a transient blip apart from
  // a real expiry: true = valid, false = 401 (invalid), null = network/unknown.
  final api = H3xBoardApiClient(serverUrl: Config.apiUrl)
    ..sessionValidator = (() async {
      try {
        return (await auth.whoami()) != null;
      } catch (_) {
        return null;
      }
    })
    ..onSessionExpired = (() => session.markUnauthenticated(reason: UnauthReason.expired));

  GetIt.I
    ..registerSingleton<SessionController>(session)
    ..registerSingleton<H3xBoardAuthService>(auth)
    ..registerSingleton<H3xBoardApiClient>(api);
}
