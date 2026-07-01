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

  @readonly
  String _searchQuery = '';

  /// Bumped on every (re)load of the board list. Board thumbnails watch it to
  /// re-fetch their screenshot when the screen is reopened — a screenshot upload
  /// doesn't change any [BoardSummary] field (it doesn't even bump updatedAt), so
  /// the cards need an explicit nudge to notice a refreshed image.
  @readonly
  int _reloadTick = 0;

  BoardsScreenViewModelBase({required super.contextAccessor});

  /// The boards to render: newest first (by creation date) and filtered by the
  /// current [searchQuery] (case-insensitive title match). We have no
  /// "recently opened" signal yet, so creation date is the ordering.
  List<BoardSummary> get visibleBoards {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _boards.toList()
        : _boards.where((b) => b.title.toLowerCase().contains(query)).toList();
    return filtered..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @action
  void setBoards(List<BoardSummary> value) => _boards = value;

  @action
  void setIsLoading(bool value) => _isLoading = value;

  @action
  void setErrorMessage(String? value) => _errorMessage = value;

  @action
  void setSearchQuery(String value) => _searchQuery = value;

  @action
  void bumpReloadTick() => _reloadTick++;

}
