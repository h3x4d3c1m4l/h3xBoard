import 'package:auto_route/annotations.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_base.dart';
import 'package:h3xboard/views/unverified_screen/unverified_screen_controller.dart';
import 'package:h3xboard/views/unverified_screen/unverified_screen_view.dart';
import 'package:h3xboard/views/unverified_screen/unverified_screen_view_model.dart';

/// The "confirm your e-mail address" waiting room.
///
/// Reached three ways: straight after registering on a server that requires
/// verification (which withholds the session until the address is confirmed),
/// from a sign-in the server turned away for the same reason, and from a
/// verification link that had already expired.
///
/// [email] is the address the mail went to, when the caller knows it. It is a
/// plain argument rather than a `@QueryParam` so it stays out of the URL; when
/// it is null (a dead link, or a page reload) the screen asks for it.
@RoutePage()
class UnverifiedScreen extends ScreenBase<UnverifiedScreenViewModel, UnverifiedScreenController, UnverifiedScreenView> {

  final String? email;

  const UnverifiedScreen({super.key, this.email});

  @override
  UnverifiedScreenController createController({
    required UnverifiedScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return UnverifiedScreenController(viewModel: viewModel, contextAccessor: contextAccessor);
  }

  @override
  UnverifiedScreenView createView({
    required UnverifiedScreenController controller,
    required UnverifiedScreenViewModel viewModel,
    required BuildContextAccessor contextAccessor,
  }) {
    return UnverifiedScreenView(viewModel: viewModel, controller: controller, contextAccessor: contextAccessor);
  }

  @override
  UnverifiedScreenViewModel createViewModel({required BuildContextAccessor contextAccessor}) {
    return UnverifiedScreenViewModel(contextAccessor: contextAccessor, email: email);
  }

}
