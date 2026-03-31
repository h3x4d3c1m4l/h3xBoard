import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/board_background.dart';

class Board extends StatefulWidget {

  final DrawingController drawingController;
  final BoardScreenViewModel viewModel;

  const Board({super.key, required this.drawingController, required this.viewModel});

  @override
  State<Board> createState() => _BoardState();

}

class _BoardState extends State<Board> {

  Offset? _pointerPosition;
  double? _eraseStrokeWidth;

  @override
  void initState() {
    widget.drawingController.drawConfig.addListener(_onDrawConfigChanged);
    super.initState();
  }

  void _onDrawConfigChanged() {
    setState(() {
      _eraseStrokeWidth = widget.drawingController.eraserContent?.paint.strokeWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) => Container(
      decoration: BoxDecoration(
        border: widget.viewModel.boardColor == Colors.white ? BoxBorder.all(width: 1, color: Colors.black12, strokeAlign: BorderSide.strokeAlignOutside) : null,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: FittedBox(
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Stack(
            children: [
              DrawingBoard(
                controller: widget.drawingController,
                background: Observer(builder: (_) {
                  Widget box = SizedBox(width: 1920, height: 1080);
                  return widget.viewModel.isChalkboard ? ChalkboardBackground(
                    boardColor: widget.viewModel.boardColor,
                    child: box,
                  ) : ColoredBox(color: widget.viewModel.boardColor, child: box);
                }),
                onPointerDown: (pde) => setState(() => _pointerPosition = pde.localPosition),
                onPointerMove: (pme) => setState(() => _pointerPosition = pme.localPosition),
                onPointerUp: (pue) => setState(() => _pointerPosition = null),
                boardPanEnabled: false,
                boardScaleEnabled: false,
              ),
              if (_eraseStrokeWidth != null)
                Positioned(
                  left: _pointerPosition!.dx - (_eraseStrokeWidth! / 2),
                  top: _pointerPosition!.dy - (_eraseStrokeWidth! / 2),
                  width: _eraseStrokeWidth,
                  height: _eraseStrokeWidth,
                  child: Container(
                    decoration: BoxDecoration(border: BoxBorder.all(), shape: BoxShape.circle, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    ));
  }

  @override
  void dispose() {
    widget.drawingController.drawConfig.removeListener(_onDrawConfigChanged);
    super.dispose();
  }

}
