import 'package:h3xboard/models/api/board_summary.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'boards_screen_view_model.g.dart';

class BoardsScreenViewModel = BoardsScreenViewModelBase with _$BoardsScreenViewModel;

abstract class BoardsScreenViewModelBase extends ScreenViewModelBase with Store {

  @readonly
  List<BoardSummary> _boards = const [];

  @readonly
  bool _isLoading = false;

  @readonly
  String? _errorMessage;

  BoardsScreenViewModelBase({required super.contextAccessor});

  @action
  void setBoards(List<BoardSummary> value) => _boards = value;

  @action
  void setIsLoading(bool value) => _isLoading = value;

  @action
  void setErrorMessage(String? value) => _errorMessage = value;

}
