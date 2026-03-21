import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/app_router.dart';

class BoardApp extends StatefulWidget {
  const BoardApp({super.key});

  @override
  State<BoardApp> createState() => _BoardAppState();
}

class _BoardAppState extends State<BoardApp> {
  final _appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    return FluentApp.router(routerConfig: _appRouter.config());
  }
}
