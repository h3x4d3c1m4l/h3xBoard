import 'package:flutter/material.dart';
import 'package:h3xboard/models/board_widget.dart';

// Natural size (in virtual canvas pixels) for each widget type.
Size naturalSizeFor(BoardWidgetType type) => switch (type) {
      BoardWidgetType.clock => const Size(300, 100),
    };

class ManipulableBoardWidget extends StatefulWidget {
  final BoardWidget boardWidget;
  final Widget child;

  final void Function(double x, double y, double rotation, double scale) onTransformChanged;

  const ManipulableBoardWidget({
    super.key,
    required this.boardWidget,
    required this.child,
    required this.onTransformChanged,
  });

  @override
  State<ManipulableBoardWidget> createState() => _ManipulableBoardWidgetState();
}

class _ManipulableBoardWidgetState extends State<ManipulableBoardWidget> {
  late double _x;
  late double _y;
  late double _rotation;
  late double _scale;

  bool _inGesture = false;
  double _gestureStartRotation = 0;
  double _gestureStartScale = 1;
  Offset? _lastLocalFocalPoint;

  @override
  void initState() {
    super.initState();
    _syncFromProps();
  }

  @override
  void didUpdateWidget(ManipulableBoardWidget old) {
    super.didUpdateWidget(old);
    if (!_inGesture) _syncFromProps();
  }

  void _syncFromProps() {
    _x = widget.boardWidget.x;
    _y = widget.boardWidget.y;
    _rotation = widget.boardWidget.rotation;
    _scale = widget.boardWidget.scale;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _inGesture = true;
    _gestureStartRotation = _rotation;
    _gestureStartScale = _scale;
    // Reset the reference point so finger-count changes don't cause a position jump.
    _lastLocalFocalPoint = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // localFocalPoint is already in canvas coordinates (inside FittedBox), so
    // no boardPixelRatio conversion needed. We compute the delta ourselves so
    // that _onScaleStart resets cleanly when a second finger is added.
    final delta = details.localFocalPoint - _lastLocalFocalPoint!;
    _lastLocalFocalPoint = details.localFocalPoint;
    setState(() {
      _x += delta.dx;
      _y += delta.dy;
      _rotation = _gestureStartRotation + details.rotation;
      _scale = (_gestureStartScale * details.scale).clamp(0.2, 5.0);
    });
    widget.onTransformChanged(_x, _y, _rotation, _scale);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _inGesture = false;
    _lastLocalFocalPoint = null;
    widget.onTransformChanged(_x, _y, _rotation, _scale);
  }

  @override
  Widget build(BuildContext context) {
    final size = naturalSizeFor(widget.boardWidget.type);

    return Positioned(
      left: _x - size.width / 2,
      top: _y - size.height / 2,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Transform.scale(
          scale: _scale,
          alignment: Alignment.center,
          child: Transform.rotate(
            angle: _rotation,
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
