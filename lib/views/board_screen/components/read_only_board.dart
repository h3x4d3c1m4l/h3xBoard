import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/background_lines.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/board_background_image.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/chalkboard_background.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/manipulable_board_widget.dart';

/// A non-interactive render of a single board: background, drawing strokes, and
/// widgets, at the canonical 1920×1080 canvas scaled with [FittedBox]. Used by
/// the live-share mirrors (external display, web viewer) to render the editor's
/// content without any controls, selection overlays, or gesture handling.
class ReadOnlyBoard extends StatelessWidget {

  final Board board;
  final List<BoardWidget> widgets;
  final DrawingController drawingController;

  /// The presenter's in-progress stroke, painted on an overlay above the
  /// committed drawing (in the same 1920×1080 canvas space) so live drawing
  /// shows without rebuilding the board. null = no overlay.
  final ValueListenable<PaintContent?>? inProgress;

  const ReadOnlyBoard({
    super.key,
    required this.board,
    required this.widgets,
    required this.drawingController,
    this.inProgress,
  });

  @override
  Widget build(BuildContext context) {
    final inProgress = this.inProgress;
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
            child: SizedBox(
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
                  if (inProgress != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _InProgressStrokePainter(inProgress)),
                      ),
                    ),
                  for (final bw in widgets)
                    ManipulableBoardWidget(
                      key: ValueKey(bw.id),
                      boardWidget: bw,
                      // Read-only mirror: widgets never edit their own config here.
                      child: descriptorFor(bw.config).buildWidget(bw.config, (_) {}),
                    ),
                ],
              ),
            ),
          ),
        ),
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
    // Mirrors the editor's background composition (board.dart): a background
    // image replaces the color/chalkboard fill, with the color underneath as
    // the loading/failure fallback.
    final backgroundFileId = board.backgroundFileId;
    if (backgroundFileId != null) {
      return BoardBackgroundImage(
        fileId: backgroundFileId,
        fallbackColor: board.backgroundColor,
        child: box,
      );
    }
    return board.isChalkboard
        ? ChalkboardBackground(boardColor: board.backgroundColor, child: box)
        : ColoredBox(color: board.backgroundColor, child: box);
  }

}

/// Paints the live in-progress stroke, repainting whenever it changes —
/// during a stroke only this layer redraws, not the board.
class _InProgressStrokePainter extends CustomPainter {

  final ValueListenable<PaintContent?> stroke;

  _InProgressStrokePainter(this.stroke) : super(repaint: stroke);

  @override
  void paint(Canvas canvas, Size size) {
    stroke.value?.draw(canvas, size, false);
  }

  @override
  bool shouldRepaint(_InProgressStrokePainter oldDelegate) => stroke != oldDelegate.stroke;

}
