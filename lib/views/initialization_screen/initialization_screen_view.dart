import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/components/animated_icon_pattern.dart';
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
    return Stack(
      children: [
        // The same drifting pencil/eraser watermark the loading dialog carries,
        // faint enough here to stay a page texture behind it.
        const Positioned.fill(child: AnimatedIconPattern()),
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    return SizedBox.expand(
      child: Observer(
        builder: (context) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ThemableLoadingDialog(
              message: viewModel.nowInitializingText ?? 'Initializing ...',
              subtitle: viewModel.retries > 0 ? 'Tried ${viewModel.retries} time(s)' : null,
            ),
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
