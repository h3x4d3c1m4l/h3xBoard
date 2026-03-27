import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';

class Board extends StatefulWidget {

  final DrawingController drawingController;

  const Board({super.key, required this.drawingController});

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
    return FittedBox(
      child: Container(
        width: 1920,
        height: 1080,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black45, width: 1),
        ),
        child: Stack(
          children: [
            DrawingBoard(
              controller: widget.drawingController,
              background: SizedBox(height: 1080, width: 1920),
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
                child: Container(decoration: BoxDecoration(
                  border: BoxBorder.all(),
                  shape: BoxShape.circle,
                  color: Colors.white,
                )),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.drawingController.drawConfig.removeListener(_onDrawConfigChanged);
    super.dispose();
  }

}
