import 'package:auto_route/auto_route.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/app_router.gr.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/dashboard_screen/dashboard_screen_controller.dart';
import 'package:h3xboard/views/dashboard_screen/dashboard_screen_view_model.dart';

class DashboardScreenView extends ScreenViewBase<DashboardScreenViewModel, DashboardScreenController> {

  const DashboardScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    return ScaffoldPage(
      content: Center(
        child: FilledButton(child: Text('Go to board'), onPressed: () => context.replaceRoute(BoardRoute())),
      ),
    );
  }

}
