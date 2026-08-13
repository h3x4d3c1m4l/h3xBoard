import 'package:h3xboard/views/base/screen_view_model_base.dart';
import 'package:mobx/mobx.dart';

part 'viewer_screen_view_model.g.dart';

class ViewerScreenViewModel = ViewerScreenViewModelBase with _$ViewerScreenViewModel;

/// Deliberately empty: everything the viewer shows comes from the
/// [LiveViewClient]'s own listenables, and the share code is typed into a
/// dialog that owns its text controller for as long as it is open.
abstract class ViewerScreenViewModelBase extends ScreenViewModelBase with Store {

  ViewerScreenViewModelBase({required super.contextAccessor});

}
