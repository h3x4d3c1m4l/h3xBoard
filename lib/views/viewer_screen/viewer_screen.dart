import 'package:auto_route/auto_route.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_base.dart';
import 'package:h3xboard/views/viewer_screen/viewer_screen_controller.dart';
import 'package:h3xboard/views/viewer_screen/viewer_screen_view.dart';
import 'package:h3xboard/views/viewer_screen/viewer_screen_view_model.dart';

/// The anonymous "second screen over the web" viewer: watches a live-shared
/// board by code. Reachable without signing in (a button on the login screen,
/// or a `/view/CODE` share link); signed-in users can watch too.
@RoutePage()
class ViewerScreen extends ScreenBase<ViewerScreenViewModel, ViewerScreenController, ViewerScreenView> {

  /// The share code from the deep link, or null to show the code-entry UI.
  final String? code;

  const ViewerScreen({super.key, @PathParam('code') this.code});

  @override
  ViewerScreenController createController({
    required ViewerScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return ViewerScreenController(initialCode: code, viewModel: viewModel, contextAccessor: contextAccessor);
  }

  @override
  ViewerScreenView createView({
    required ViewerScreenController controller,
    required ViewerScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return ViewerScreenView(viewModel: viewModel, controller: controller, contextAccessor: contextAccessor);
  }

  @override
  ViewerScreenViewModel createViewModel({required BuildContextAccessor contextAccessor}) {
    return ViewerScreenViewModel(contextAccessor: contextAccessor);
  }

}
