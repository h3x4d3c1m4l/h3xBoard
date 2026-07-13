import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/board_screen/components/board_canvas.dart';
import 'package:h3xboard/views/board_screen/drawing_serialization.dart';

/// One sub-board queued for rasterisation: everything needed to paint it, plus
/// the key of the [RepaintBoundary] the exporter will call `toImage` on.
class BoardExportPage {

  final Board board;
  final List<BoardWidget> widgets;
  final List<Map<String, dynamic>> drawing;
  final GlobalKey boundaryKey;

  BoardExportPage({
    required this.board,
    required this.widgets,
    required this.drawing,
  }) : boundaryKey = GlobalKey();

}

/// Renders every [BoardExportPage] offscreen, each in its own [RepaintBoundary]
/// at the full 1920×1080 canvas, so the exporter can rasterise sub-boards the
/// user isn't currently looking at. Mounted into the screen's [Overlay] for the
/// duration of an export and removed afterwards.
///
/// Two things make this work:
///
///  * Each page gets its **own** [DrawingController], hydrated from the stored
///    stroke JSON — the editor's live controller only ever holds the active
///    sub-board's strokes, and must not be touched.
///  * The stage is laid out at its natural size but painted at a scale of
///    1/1000, inside a zero-size [Positioned] — so it is invisible and takes no
///    space, yet is still *painted*, which a boundary needs before `toImage`
///    will produce anything. A [RepaintBoundary] rasterises its own layer at its
///    own logical size, so the ancestor [Transform] does not shrink the output:
///    the capture still comes out at 1920×1080 × the requested pixel ratio.
class BoardExportStage extends StatefulWidget {

  final List<BoardExportPage> pages;

  /// Downloads the pages' background images. `null` renders them as their plain
  /// background color instead (see [BoardCanvas.fileService]).
  final H3xBoardFileService? fileService;

  const BoardExportStage({
    super.key,
    required this.pages,
    this.fileService,
  });

  @override
  State<BoardExportStage> createState() => _BoardExportStageState();

}

class _BoardExportStageState extends State<BoardExportStage> {

  final List<DrawingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    for (final page in widget.pages) {
      final controller = DrawingController();
      if (page.drawing.isNotEmpty) {
        controller.addContents(restoreDrawingContents(page.drawing));
      }
      _controllers.add(controller);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      width: 0,
      height: 0,
      child: IgnorePointer(
        // The zero-size Positioned hands down tight 0×0 constraints; loosen them
        // so the pages can lay out at their natural 1920×1080.
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.scale(
            scale: 0.001,
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.pages.length; i++)
                  RepaintBoundary(
                    key: widget.pages[i].boundaryKey,
                    child: BoardCanvas(
                      board: widget.pages[i].board,
                      widgets: widget.pages[i].widgets,
                      drawingController: _controllers[i],
                      fileService: widget.fileService,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
