import 'package:flutter/widgets.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';

Size naturalSizeFor(BoardWidgetConfig config) => descriptorFor(config).naturalSize;

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
    final size = naturalSizeFor(boardWidget.config);
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
