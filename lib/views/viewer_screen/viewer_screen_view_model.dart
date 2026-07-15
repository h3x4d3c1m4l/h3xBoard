import 'package:flutter/widgets.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'viewer_screen_view_model.g.dart';

class ViewerScreenViewModel = ViewerScreenViewModelBase with _$ViewerScreenViewModel;

abstract class ViewerScreenViewModelBase extends ScreenViewModelBase with Store {

  final codeController = TextEditingController();

  ViewerScreenViewModelBase({required super.contextAccessor});

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

}
