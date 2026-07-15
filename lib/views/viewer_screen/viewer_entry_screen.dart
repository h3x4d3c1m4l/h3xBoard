import 'package:auto_route/annotations.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/viewer_screen/viewer_screen.dart';

/// The code-entry face of the viewer at its own path (`/view`). auto_route
/// requires every route name to map to exactly one path, so the "no code yet"
/// case can't share `ViewerRoute` (`/view/:code`) — this thin page renders
/// the same [ViewerScreen], which shows its code-entry UI when [ViewerScreen.code]
/// is null. Submitting a code navigates to the real `/view/:code` route.
@RoutePage()
class ViewerEntryScreen extends StatelessWidget {

  const ViewerEntryScreen({super.key});

  @override
  Widget build(BuildContext context) => const ViewerScreen();

}
