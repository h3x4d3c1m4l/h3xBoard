import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/balanced_side.dart';
import 'package:h3xboard/views/board_screen/components/buttons/exit_button.dart';
import 'package:h3xboard/views/board_screen/components/menu_controls.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/sub_board_tab_bar.dart';

/// The board screen's top bar: an Exit button on the left, the sub-board switcher
/// centred, and the save indicator + menu on the right. Styled to match the
/// Boards screen header (card background with a bottom hairline).
class BoardTopBar extends StatelessWidget {

  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  const BoardTopBar({super.key, required this.controller, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        border: Border(
          bottom: BorderSide(color: theme.resources.controlStrokeColorDefault),
        ),
      ),
      // Gutter + max-width constraint mirror the Boards screen so both top bars
      // line up with the board grid's content width.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kContentHorizontalPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  BalancedSide(
                    alignment: AlignmentDirectional.centerStart,
                    counterweight: MenuControls(controller: controller, viewModel: viewModel),
                    child: ExitButton(controller: controller),
                  ),
                  // The sub-board switcher fills the space between the fixed exit
                  // button and menu controls, and stays centred within it. When
                  // there are too many tabs it collapses the overflow behind a
                  // "more" button instead of pushing the bar wider.
                  Expanded(
                    child: Container(
                      margin: .symmetric(horizontal: 64),
                      alignment: .center,
                      child: Observer(
                        builder: (_) => SubBoardTabBar(
                          subBoards: viewModel.subBoards.toList(),
                          activeSubBoardId: viewModel.activeSubBoardId,
                          onSwitchSubBoard: controller.onSwitchSubBoard,
                          onAddSubBoard: controller.onAddSubBoard,
                          onRemoveSubBoard: controller.onRemoveSubBoard,
                          onRenameSubBoard: controller.onRenameSubBoard,
                        ),
                      ),
                    ),
                  ),
                  BalancedSide(
                    alignment: AlignmentDirectional.centerEnd,
                    counterweight: ExitButton(controller: controller),
                    child: MenuControls(controller: controller, viewModel: viewModel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
