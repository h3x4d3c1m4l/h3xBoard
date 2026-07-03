import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/widgets/continuous_text_box.dart';
import 'package:h3xboard/widgets/themable_content_dialog.dart';

/// Opens the custom color picker seeded with [initial] and resolves to the
/// chosen [Color], or `null` if the dialog was dismissed without confirming.
Future<Color?> showColorPicker(BuildContext context, {required Color initial}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => ColorPickerDialog(initial: initial),
    barrierDismissible: true,
  );
}

/// A compact HSV color picker: a saturation/value field, a hue slider and a hex
/// input, all kept in sync. Pops the picked [Color] on OK, or `null` on cancel.
class ColorPickerDialog extends StatefulWidget {

  final Color initial;

  const ColorPickerDialog({super.key, required this.initial});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();

}

class _ColorPickerDialogState extends State<ColorPickerDialog> {

  // The fixed dimensions the gesture math is computed against.
  static const double _fieldWidth = 280;
  static const double _fieldHeight = 180;
  static const double _sliderHeight = 24;

  late HSVColor _hsv = HSVColor.fromColor(Color(widget.initial.toARGB32()).withValues(alpha: 1));
  final TextEditingController _hexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncHexField();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  void _syncHexField() {
    final hex = _color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    _hexController.text = '#$hex';
  }

  void _setHsv(HSVColor value) {
    setState(() => _hsv = value);
    _syncHexField();
  }

  void _onHexSubmitted(String raw) {
    final parsed = _parseHex(raw);
    if (parsed == null) {
      _syncHexField();
      return;
    }
    _setHsv(HSVColor.fromColor(parsed));
  }

  void _onFieldPan(Offset localPosition) {
    final saturation = (localPosition.dx / _fieldWidth).clamp(0.0, 1.0);
    final value = (1 - localPosition.dy / _fieldHeight).clamp(0.0, 1.0);
    _setHsv(_hsv.withSaturation(saturation).withValue(value));
  }

  void _onHuePan(Offset localPosition) {
    final hue = (localPosition.dx / _fieldWidth).clamp(0.0, 1.0) * 360;
    _setHsv(_hsv.withHue(hue));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    final theme = FluentTheme.of(context);

    return ThemableContentDialog(
      constraints: const BoxConstraints(maxWidth: 360),
      title: Text(loc.colorPicker_title),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSaturationValueField(),
            const SizedBox(height: 16),
            _buildHueSlider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.resources.controlStrokeColorDefault),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ContinuousTextBox(
                    controller: _hexController,
                    prefix: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: Text(loc.colorPicker_hex, style: theme.typography.caption),
                    ),
                    onSubmitted: _onHexSubmitted,
                    onTapOutside: (_) => _onHexSubmitted(_hexController.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.colorPicker_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: Text(loc.colorPicker_done),
        ),
      ],
    );
  }

  Widget _buildSaturationValueField() {
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    final thumbLeft = _hsv.saturation * _fieldWidth;
    final thumbTop = (1 - _hsv.value) * _fieldHeight;

    return _GestureSurface(
      onInteract: _onFieldPan,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kControlCornerRadius / 2),
        child: SizedBox(
          width: _fieldWidth,
          height: _fieldHeight,
          child: Stack(
            children: [
              // White → hue across, then transparent → black down.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white, hueColor]),
                ),
                child: const SizedBox.expand(),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
                child: SizedBox.expand(),
              ),
              Positioned(
                left: thumbLeft - 8,
                top: thumbTop - 8,
                child: const _Thumb(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHueSlider() {
    final thumbLeft = (_hsv.hue / 360) * _fieldWidth;
    return _GestureSurface(
      onInteract: _onHuePan,
      child: SizedBox(
        width: _fieldWidth,
        height: _sliderHeight,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_sliderHeight / 2),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            Positioned(
              left: (thumbLeft - 8).clamp(0.0, _fieldWidth - 16),
              top: (_sliderHeight - 16) / 2,
              child: const _Thumb(),
            ),
          ],
        ),
      ),
    );
  }

}

/// Wraps [child] with tap/drag handling that reports the local position of the
/// pointer (clamped to the child) through [onInteract].
class _GestureSurface extends StatelessWidget {

  final Widget child;
  final void Function(Offset localPosition) onInteract;

  const _GestureSurface({required this.child, required this.onInteract});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) => onInteract(d.localPosition),
      onPanStart: (d) => onInteract(d.localPosition),
      onPanUpdate: (d) => onInteract(d.localPosition),
      child: child,
    );
  }

}

/// A small ring thumb used for both the SV field and the hue slider.
class _Thumb extends StatelessWidget {

  const _Thumb();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 2),
          ],
        ),
      ),
    );
  }

}

/// Parses `#RRGGBB` / `RRGGBB` (and the 8-digit `#AARRGGBB`) into an opaque
/// [Color], or `null` when the string isn't a valid hex color.
Color? _parseHex(String raw) {
  var hex = raw.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(value).withValues(alpha: 1);
}
