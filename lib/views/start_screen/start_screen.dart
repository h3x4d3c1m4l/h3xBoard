import 'package:auto_route/annotations.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_base.dart';
import 'package:h3xboard/views/start_screen/start_screen_controller.dart';
import 'package:h3xboard/views/start_screen/start_screen_view.dart';
import 'package:h3xboard/views/start_screen/start_screen_view_model.dart';

@RoutePage()
class StartScreen extends ScreenBase<StartScreenViewModel, StartScreenController, StartScreenView> {

  const StartScreen({super.key});

  @override
  StartScreenController createController({
    required StartScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return StartScreenController(viewModel: viewModel, contextAccessor: contextAccessor);
  }

  @override
  StartScreenView createView({
    required StartScreenController controller,
    required StartScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return StartScreenView(viewModel: viewModel, controller: controller, contextAccessor: contextAccessor);
  }

  @override
  StartScreenViewModel createViewModel({required BuildContextAccessor contextAccessor}) {
    return StartScreenViewModel(contextAccessor: contextAccessor);
  }

}
