import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/board_canvas.dart';

/// A non-interactive render of a single board: background, drawing strokes, and
/// widgets, at the canonical 1920×1080 canvas scaled with [FittedBox]. Used by
/// the external display to mirror the editor without any controls, selection
/// overlays, or gesture handling.
class ReadOnlyBoard extends StatelessWidget {

  final Board board;
  final List<BoardWidget> widgets;
  final DrawingController drawingController;

  const ReadOnlyBoard({
    super.key,
    required this.board,
    required this.widgets,
    required this.drawingController,
  });

  @override
  Widget build(BuildContext context) {
    // Scale the fixed 1920×1080 canvas up to the largest 16:9 rectangle that
    // fits the external screen, centered. On a non-16:9 display the leftover
    // space shows as white bars (painted behind by the parent); the board itself
    // is framed with a soft square border and a subtle drop shadow — a more
    // restrained take on the memo-note widget's lifted-paper look.
    return Center(
      child: AspectRatio(
        aspectRatio: 1920 / 1080,
        child: Container(
          decoration: BoxDecoration(
            border: BoxBorder.all(width: 1, color: Colors.black.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            // No file service: this runs in the external display's own app entry
            // point, which has no way to download a background image (see
            // [BoardCanvas.fileService]).
            child: BoardCanvas(
              board: board,
              widgets: widgets,
              drawingController: drawingController,
            ),
          ),
        ),
      ),
    );
  }

}
