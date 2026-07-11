import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'initialization_screen_view_model.g.dart';

class InitializationScreenViewModel = InitializationScreenViewModelBase with _$InitializationScreenViewModel;

abstract class InitializationScreenViewModelBase extends ScreenViewModelBase with Store {

  /// The bootstrap step currently in flight, or `null` before the first step
  /// reports in.
  @readonly
  String? _nowInitializingText;

  /// How often the current step has been retried (0 on the first attempt).
  @readonly
  int _retries = 0;

  InitializationScreenViewModelBase({required super.contextAccessor});

  @action
  void setProgress({required String nowInitializingText, required int retries}) {
    _nowInitializingText = nowInitializingText;
    _retries = retries;
  }

  @action
  void resetProgress() {
    _nowInitializingText = null;
    _retries = 0;
  }

}
