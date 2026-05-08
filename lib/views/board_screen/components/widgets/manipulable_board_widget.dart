import 'package:flutter/material.dart';
import 'package:h3xboard/models/board_widget.dart';

// Natural size (in virtual canvas pixels) for each widget type.
Size naturalSizeFor(BoardWidgetType type) => switch (type) {
      BoardWidgetType.clock => const Size(300, 100),
    };

class ManipulableBoardWidget extends StatelessWidget {
  final BoardWidget boardWidget;
  final Widget child;

  const ManipulableBoardWidget({
    super.key,
    required this.boardWidget,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final size = naturalSizeFor(boardWidget.type);
    final scaledWidth = size.width * boardWidget.scale;
    final scaledHeight = size.height * boardWidget.scale;

    return Positioned(
      left: boardWidget.x - scaledWidth / 2,
      top: boardWidget.y - scaledHeight / 2,
      width: scaledWidth,
      height: scaledHeight,
      child: Transform.rotate(
        angle: boardWidget.rotation,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: child,
          ),
        ),
      ),
    );
  }
}
