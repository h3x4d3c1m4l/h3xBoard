import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/components/dialogs/themable_loading_dialog.dart';
import 'package:h3xboard/views/components/server_chip.dart';
import 'package:h3xboard/views/initialization_screen/initialization_screen_controller.dart';
import 'package:h3xboard/views/initialization_screen/initialization_screen_view_model.dart';

class InitializationScreenView extends ScreenViewBase<InitializationScreenViewModel, InitializationScreenController> {

  const InitializationScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    return SizedBox.expand(
      child: Observer(
        builder: (context) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ThemableLoadingDialog(
              message: viewModel.nowInitializingText ?? 'Initializing ...',
              subtitle: viewModel.retries > 0 ? 'Tried ${viewModel.retries} time(s)' : null,
            ),
            // The escape hatch when the configured server is unreachable: the
            // steps above would otherwise retry forever with no way to see, let
            // alone fix, which host the app is stuck on.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 368),
              child: ServerChip(
                serverUrl: controller.serverUrl,
                onEdit: () => showServerUrlDialog(
                  context,
                  currentUrl: controller.serverUrl,
                  onSave: controller.changeServer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
