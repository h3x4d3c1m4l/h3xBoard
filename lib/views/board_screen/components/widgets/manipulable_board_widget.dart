import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';

typedef WidgetSettingsBuilder = List<MenuFlyoutItemBase> Function(BuildContext context);

Size naturalSizeFor(BoardWidgetConfig config) => descriptorFor(config).naturalSize(config);

/// The one place a placement becomes pixels: a widget laid out at its natural
/// size, stretched to fill [rect] and turned by [rotation] about its centre.
///
/// Split out of [ManipulableBoardWidget] so the full-screen flight can drive the
/// *same* composition with a lerped rect. That is what makes the flying copy
/// pixel-identical to the board copy at the start of the flight — by
/// construction rather than by two files agreeing — which is in turn what lets
/// the board copy be hidden for the whole flight with no visible seam.
///
/// Emits a [Positioned], so it must be a direct child of a [Stack].
class PlacedBoardWidget extends StatelessWidget {

  final Rect rect;
  final double rotation;

  /// The size [child] is laid out at before being scaled into [rect].
  final Size naturalSize;

  final Widget child;

  const PlacedBoardWidget({
    super.key,
    required this.rect,
    required this.rotation,
    required this.naturalSize,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: Transform.rotate(
        angle: rotation,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: naturalSize.width,
            height: naturalSize.height,
            child: child,
          ),
        ),
      ),
    );
  }

}

class ManipulableBoardWidget extends StatelessWidget {

  final BoardWidget boardWidget;
  final Widget child;

  const ManipulableBoardWidget({
    super.key,
    required this.boardWidget,
    required this.child,
  });

  /// Where [boardWidget] sits in canvas space. `x`/`y` are its centre.
  static Rect rectFor(BoardWidget boardWidget) {
    final size = naturalSizeFor(boardWidget.config);
    return Rect.fromCenter(
      center: Offset(boardWidget.x, boardWidget.y),
      width: size.width * boardWidget.scale,
      height: size.height * boardWidget.scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlacedBoardWidget(
      rect: rectFor(boardWidget),
      rotation: boardWidget.rotation,
      naturalSize: naturalSizeFor(boardWidget.config),
      child: child,
    );
  }

}
