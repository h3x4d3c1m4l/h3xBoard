import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/theme/theme.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/toggle_button_toolbar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A tool button's label must take its color from the button, not from a
/// [TextStyle] of its own.
///
/// Fluent resolves the text color as `textStyle?.color ?? foregroundColor`
/// (`buttons/base.dart`), so any style carrying a color — `typography.caption`
/// does — pins the label and strands it on the accent fill when the tool goes
/// active: black text beside a white icon. The label's *size* therefore lives on
/// the `toolbarItem` role's `textStyle` (colorless), never on the widget.
///
/// The icon is asserted alongside it because agreement between the two is the
/// symptom that is actually visible on screen.
void _noop() {}

/// The label and icon [ToolButton] renders, once its state has settled.
///
/// [ToolButton] builds its button twice — the visible one and an invisible
/// size-maintaining copy behind the disabled-tap affordance — so both finders
/// take the first (visible) match.
({Color? label, Color? icon}) _colors(WidgetTester tester) {
  final rich = tester.widget<RichText>(
    find.descendant(of: find.text('Draw').first, matching: find.byType(RichText)).first,
  );
  final iconFinder = find.byIcon(LucideIcons.pen).first;
  return (
    label: rich.text.style?.color,
    icon: tester.widget<Icon>(iconFinder).color ?? IconTheme.of(tester.element(iconFinder)).color,
  );
}

Future<void> _pumpToolbar(WidgetTester tester, {required bool checked}) async {
  await tester.pumpWidget(FluentApp(
    theme: buildAppTheme(),
    home: Center(
      child: ToggleButtonToolbar(buttons: [
        ToolButton(icon: LucideIcons.pen, title: 'Draw', checked: checked, onPressed: _noop),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an idle tool button draws its label and icon in the same dark foreground', (tester) async {
    await _pumpToolbar(tester, checked: false);

    final colors = _colors(tester);
    expect(colors.label, isNotNull);
    expect(colors.label, colors.icon);
    expect(colors.label!.a, greaterThan(0.5), reason: 'legible on the toolbar surface');
    expect(colors.label!.r, lessThan(0.5), reason: 'dark on a light bar, not white');
  });

  testWidgets('the active tool draws its label white, agreeing with its icon on the accent fill', (tester) async {
    await _pumpToolbar(tester, checked: true);

    final colors = _colors(tester);
    expect(colors.label, colors.icon, reason: 'black label beside a white icon is the regression');
    expect(colors.label, Colors.white);
  });

  testWidgets('pressing dims the label along with the icon', (tester) async {
    await _pumpToolbar(tester, checked: false);
    final idle = _colors(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Draw').first));
    addTearDown(gesture.up);
    // The text color is animated and the icon's is not, so settle before reading
    // or the label is caught mid-transition.
    await tester.pumpAndSettle();

    final pressed = _colors(tester);
    expect(pressed.label, isNot(idle.label), reason: 'the label has to react to the press at all');
    expect(pressed.label, pressed.icon);
  });
}
