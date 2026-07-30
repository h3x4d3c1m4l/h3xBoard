import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';

/// The row of one-tap stroke width presets shown at the top of every drawing
/// tool's flyout, above the slider that fine-tunes the same value.
///
/// Dots are sized by their position in the row rather than by their true pixel
/// width: the row's job is to rank five options at a glance, and drawing a 64px
/// highlighter dot at scale would either dwarf its neighbours or push the row
/// wider than the flyout. The exact width stays readable from the slider and
/// the preview swatch next to it.
class StrokePresetRow extends StatelessWidget {

  final List<double> presets;
  final double value;
  final ValueChanged<double> onPresetSelected;

  /// Painted into the dots, so a preset previews the colour it draws with.
  final Color? color;

  /// Highlighter dots are rounded squares, matching the marker preview beside
  /// the slider; every other tool draws round.
  final bool isSquare;

  /// The eraser has no colour of its own, so its dots are outlined instead.
  final bool isOutlined;

  const StrokePresetRow({
    super.key,
    required this.presets,
    required this.value,
    required this.onPresetSelected,
    this.color,
    this.isSquare = false,
    this.isOutlined = false,
  });

  static const double _minDotSize = 4;
  static const double _maxDotSize = 24;
  static const double _dotBoxSize = 24;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        for (final (index, preset) in presets.indexed)
          ToggleButton(
            // A dragged slider lands between presets and simply leaves them all
            // unchecked, which is the honest state.
            checked: preset == value,
            onChanged: (_) => onPresetSelected(preset),
            child: SizedBox.square(
              dimension: _dotBoxSize,
              child: Center(child: _buildDot(context, index)),
            ),
          ),
      ],
    );
  }

  Widget _buildDot(BuildContext context, int index) {
    final t = presets.length > 1 ? index / (presets.length - 1) : 1.0;
    final size = lerpDouble(_minDotSize, _maxDotSize, t)!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOutlined ? Colors.white : color ?? FluentTheme.of(context).inactiveColor,
        shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isSquare ? BorderRadius.circular(2) : null,
        border: isOutlined ? Border.all() : null,
      ),
    );
  }

}
