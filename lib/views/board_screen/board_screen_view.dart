import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/models/app_settings_enums.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/board.dart';
import 'package:h3xboard/views/board_screen/components/board_scaffold.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/board_top_bar.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/drawing_toolbar.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/tool_toolbar.dart';

class BoardScreenView extends ScreenViewBase<BoardScreenViewModel, BoardScreenController> {
  const BoardScreenView({required super.viewModel, required super.controller, required super.contextAccessor});

  @override
  Widget get body {
    // canPop is always false: every exit (close button, system/browser back)
    // is routed through the controller so pending changes are flushed first.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(controller.requestClose());
      },
      // ScaffoldPage paints the theme's scaffoldBackgroundColor behind the board.
      child: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Observer(
      builder: (context) {
        if (viewModel.isLoading) {
          return const Center(child: ProgressRing());
        }

        if (viewModel.loadError != null) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: InfoBar(
                title: Text(viewModel.loadError!),
                severity: InfoBarSeverity.error,
                action: Button(
                  onPressed: controller.retryLoad,
                  child: Text(localizations.boardScreen_retry),
                ),
              ),
            ),
          );
        }

        return _buildBoard();
      },
    );
  }

  Widget _buildBoard() {
    final appSettings = GetIt.I<AppSettingsController>();

    // The central content: the board canvas, locked to the 1920×1080 (16:9)
    // canvas ratio so its rounded border hugs the actual (fully drawable) board
    // and any outside-docked bar sits right against the board's real edge. The
    // grey page background simply shows around it.
    final center = AspectRatio(
      aspectRatio: 1920 / 1080,
      child: LayoutBuilder(
        builder: (context, constraints) {
          viewModel.updateResizeFactor(constraints);
          return Board(
            drawingController: controller.drawingController,
            viewModel: viewModel,
            captureKey: controller.boardCaptureKey,
            onDeleteWidget: controller.onDeleteWidget,
            onWidgetConfigChanged: controller.onWidgetConfigChanged,
            onWidgetVisibilityChanged: controller.onWidgetVisibilityChanged,
            onWidgetTransformStart: controller.onWidgetTransformStart,
            onWidgetTransformEnd: controller.onWidgetTransformEnd,
            onDrawingStrokeStart: controller.onDrawingStrokeStart,
            onDrawingStrokeEnd: controller.onDrawingStrokeEnd,
            onMoveWidgetToTop: controller.onMoveWidgetToTop,
            onMoveWidgetUp: controller.onMoveWidgetUp,
            onMoveWidgetDown: controller.onMoveWidgetDown,
            onMoveWidgetToBottom: controller.onMoveWidgetToBottom,
          );
        },
      ),
    );

    // The top bar holds the exit button, sub-board switcher and save+menu
    // controls; the board and its docked bars fill the space below it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BoardTopBar(controller: controller, viewModel: viewModel),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Observer(
              builder: (_) {
                final colorBarPos = appSettings.colorBarPosition;
                final toolBarPos = appSettings.toolBarPosition;
                final toolBar = DockedBar(
                  position: toolBarPos,
                  inside: appSettings.toolBarInside,
                  bar: ToolToolbar(
                    controller: controller,
                    viewModel: viewModel,
                    direction: toolBarPos.axis,
                  ),
                );
                final colorBar = DockedBar(
                  position: colorBarPos,
                  inside: appSettings.colorBarInside,
                  bar: Observer(
                    builder: (_) => DrawingToolbar(
                      activeColor: viewModel.drawingTools.activeColor,
                      onColorButtonPressed: controller.onColorButtonPressed,
                      direction: colorBarPos.axis,
                    ),
                  ),
                );
                // Order only matters when both bars share an edge (BoardScaffold stacks
                // same-edge bars in list order); on different edges it's harmless.
                return BoardScaffold(
                  center: center,
                  bars: appSettings.barOrder == BarOrder.colorBarFirst ? [colorBar, toolBar] : [toolBar, colorBar],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
