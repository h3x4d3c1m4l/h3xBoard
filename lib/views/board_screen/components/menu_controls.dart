import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/services/live_share/board_mirroring.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/laser_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/menu_button.dart';
import 'package:h3xboard/views/board_screen/components/buttons/share_button.dart';
import 'package:h3xboard/views/board_screen/components/save_status_indicator.dart';

/// The top bar's right-hand cluster: laser, save indicator, share and menu.
class MenuControls extends StatelessWidget {

  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  const MenuControls({super.key, required this.controller, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        // The laser appears only while the board is actually being mirrored: a
        // dot nobody else can see points at nothing.
        Observer(
          builder: (_) => isBoardMirrored
              ? LaserButton(controller: controller, viewModel: viewModel)
              : const SizedBox.shrink(),
        ),
        Observer(builder: (_) => SaveStatusIndicator(status: viewModel.saveStatus)),
        const ShareButton(),
        MenuButton(controller: controller, viewModel: viewModel),
      ],
    );
  }

}
