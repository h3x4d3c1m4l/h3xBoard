import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'board_screen_view_model.g.dart';

class BoardScreenViewModel = BoardScreenViewModelBase with _$BoardScreenViewModel;

abstract class BoardScreenViewModelBase extends ScreenViewModelBase with Store {

  BoardScreenViewModelBase({
    required super.contextAccessor,
  });

}
