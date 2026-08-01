import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/components/continuous_combo_box.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The backdrops the gallery can sit on. A button is only as legible as the
/// surface behind it, and the app puts them on all of these: a dialog's white
/// panel, its gray actions bar, the board's paper, a chalkboard, the accent.
enum _GalleryBackdrop {

  white('White', Color(0xFFFFFFFF)),
  mica('Actions bar', Color(0xFFF3F3F3)),
  scaffold('Scaffold', Color(0xFFEAE9E6)),
  slate('Slate', Color(0xFF6B7280)),
  chalkboard('Chalkboard', Color(0xFF1F2A24)),
  accent('Accent', Color(0xFF00FF80));

  const _GalleryBackdrop(this.label, this.color);

  final String label;
  final Color color;

  /// Whether text drawn on this backdrop should be light.
  bool get isDark => color.computeLuminance() < 0.4;

}

/// Opens the fluent_ui widget gallery — a debug-only page showing one of every
/// button type the app can use, over a switchable backdrop.
Future<void> showWidgetGalleryDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const WidgetGalleryDialog(),
);

/// Every fluent_ui button type side by side, so a theme change can be eyeballed
/// against each of them at once — including the ones fluent builds out of a
/// plain [Button] under the hood ([ComboBox], [DropDownButton], [SplitButton]),
/// which is exactly where a `defaultButtonStyle` change leaks.
///
/// Debug-only: reachable from the Alt+D panel, never from the product UI.
class WidgetGalleryDialog extends StatefulWidget {

  const WidgetGalleryDialog({super.key});

  @override
  State<WidgetGalleryDialog> createState() => _WidgetGalleryDialogState();

}

class _WidgetGalleryDialogState extends State<WidgetGalleryDialog> {

  _GalleryBackdrop _backdrop = _GalleryBackdrop.white;

  bool _toggleChecked = true;
  bool _switchValue = true;
  String _comboValue = 'Medium';

  @override
  Widget build(BuildContext context) {
    return ThemableContentDialog(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
      showBackgroundPattern: false,
      title: const Text('fluent_ui gallery'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          _buildBackdropPicker(),
          Flexible(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: _backdrop.color,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.appTheme.buttons.borderColor),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                // The gallery's own text has to survive a dark backdrop; the
                // buttons themselves are deliberately left to the app theme.
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: _backdrop.isDark ? Colors.white : Colors.black),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      _row('Button', [
                        Button(onPressed: () {}, child: const Text('Button')),
                        Button(onPressed: null, child: const Text('Disabled')),
                      ]),
                      _row('FilledButton', [
                        FilledButton(onPressed: () {}, child: const Text('Filled')),
                        FilledButton(onPressed: null, child: const Text('Disabled')),
                      ]),
                      _row('OutlinedButton', [
                        OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
                        OutlinedButton(onPressed: null, child: const Text('Disabled')),
                      ]),
                      _row('HyperlinkButton', [
                        HyperlinkButton(onPressed: () {}, child: const Text('Hyperlink')),
                        HyperlinkButton(onPressed: null, child: const Text('Disabled')),
                      ]),
                      _row('IconButton', [
                        IconButton(icon: const Icon(LucideIcons.pencil), onPressed: () {}),
                        IconButton(icon: const Icon(LucideIcons.trash2), onPressed: null),
                      ]),
                      _row('ToggleButton', [
                        ToggleButton(
                          checked: _toggleChecked,
                          onChanged: (v) => setState(() => _toggleChecked = v),
                          child: const Text('Toggle'),
                        ),
                        ToggleButton(checked: false, onChanged: null, child: const Text('Disabled')),
                      ]),
                      _row('ToggleSwitch', [
                        ToggleSwitch(
                          checked: _switchValue,
                          onChanged: (v) => setState(() => _switchValue = v),
                          content: const Text('Switch'),
                        ),
                      ]),
                      _row('SplitButton', [
                        SplitButton(
                          flyout: const FlyoutContent(child: Text('Split button flyout')),
                          onInvoked: () {},
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Text('Split'),
                          ),
                        ),
                      ]),
                      _row('DropDownButton', [
                        DropDownButton(
                          title: const Text('Drop down'),
                          items: [
                            MenuFlyoutItem(text: const Text('First'), onPressed: () {}),
                            MenuFlyoutItem(text: const Text('Second'), onPressed: () {}),
                          ],
                        ),
                      ]),
                      _row('ContinuousComboBox', [
                        ContinuousComboBox<String>(
                          value: _comboValue,
                          items: [
                            for (final size in ['Small', 'Medium', 'Large'])
                              ComboBoxItem(value: size, child: Text(size)),
                          ],
                          onChanged: (v) => setState(() => _comboValue = v ?? _comboValue),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  /// The backdrop switcher: one toggle per swatch, so the whole gallery can be
  /// re-checked against another surface without leaving the dialog.
  Widget _buildBackdropPicker() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final backdrop in _GalleryBackdrop.values)
          ToggleButton(
            checked: _backdrop == backdrop,
            onChanged: (_) => setState(() => _backdrop = backdrop),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: ShapeDecoration(
                    color: backdrop.color,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: context.appTheme.buttons.borderColor),
                    ),
                  ),
                ),
                Text(backdrop.label),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(String label, List<Widget> samples) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 8, children: samples),
        ),
      ],
    );
  }

}
