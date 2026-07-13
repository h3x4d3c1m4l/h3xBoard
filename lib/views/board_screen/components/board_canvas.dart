import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/background_lines.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/board_background_image.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/chalkboard_background.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';

/// The board's visual layers — background (color/chalkboard/image + line
/// overlay), drawing strokes, and widget bodies — at the canonical 1920×1080
/// canvas, with no chrome, gestures or scaling of any kind.
///
/// This is what a board *is*, stripped of the editor: the external display
/// mirror (`ReadOnlyBoard`) and the exporter (`BoardExportStage`) both render
/// it, and the editor's own `Board` paints the same three layers inside its
/// capture boundary. Callers are responsible for fitting it (via [FittedBox] or
/// a [Transform]) — it always lays out at exactly 1920×1080.
class BoardCanvas extends StatelessWidget {

  final Board board;
  final List<BoardWidget> widgets;
  final DrawingController drawingController;

  /// Fetches the board's [Board.backgroundFileId] image. `null` when the caller
  /// has no file service to offer — the external display runs as a second app
  /// entry point with no GetIt, API client or cookie jar, so it cannot download
  /// anything and falls back to the plain background color.
  final H3xBoardFileService? fileService;

  const BoardCanvas({
    super.key,
    required this.board,
    required this.widgets,
    required this.drawingController,
    this.fileService,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1920,
      height: 1080,
      child: Stack(
        children: [
          IgnorePointer(
            child: DrawingBoard(
              controller: drawingController,
              background: _buildBackground(),
              boardPanEnabled: false,
              boardScaleEnabled: false,
            ),
          ),
          for (final bw in widgets)
            ManipulableBoardWidget(
              key: ValueKey(bw.id),
              boardWidget: bw,
              // Static render: widgets never edit their own config here.
              child: IgnorePointer(child: descriptorFor(bw.config).buildWidget(bw.config, (_) {})),
            ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    final Widget box = BackgroundLines(
      pattern: board.linePattern,
      spacing: board.lineSpacing,
      color: board.lineColor,
      child: const SizedBox(width: 1920, height: 1080),
    );
    final backgroundFileId = board.backgroundFileId;
    final fileService = this.fileService;
    if (backgroundFileId != null && fileService != null) {
      return BoardBackgroundImage(
        fileId: backgroundFileId,
        fallbackColor: board.backgroundColor,
        fileService: fileService,
        child: box,
      );
    }
    return board.isChalkboard
        ? ChalkboardBackground(boardColor: board.backgroundColor, child: box)
        : ColoredBox(color: board.backgroundColor, child: box);
  }

}
