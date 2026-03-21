import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'dashboard_screen_view_model.g.dart';

class DashboardScreenViewModel = DashboardScreenViewModelBase with _$DashboardScreenViewModel;

abstract class DashboardScreenViewModelBase extends ScreenViewModelBase with Store {

  DashboardScreenViewModelBase({
    required super.contextAccessor,
  });

}
