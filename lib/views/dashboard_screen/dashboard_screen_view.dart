import 'package:flutter/widgets.dart';
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
    return Text("Hello from DashboardScreen!");
  }

}
