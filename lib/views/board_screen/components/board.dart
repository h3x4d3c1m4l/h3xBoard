import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';

class Board extends StatelessWidget {

  final DrawingController drawingController;

  const Board({super.key, required this.drawingController});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Container(
        width: 1920,
        height: 1080,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black45, width: 1),
        ),
        child: DrawingBoard(
          controller: drawingController,
          background: SizedBox(height: 1080, width: 1920),
          boardPanEnabled: false,
          boardScaleEnabled: false,
        ),
      ),
    );
  }

}
