import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/theme/theme.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:h3xboard/views/components/keyboard_dismisser.dart';

/// Hosts a dialog under [KeyboardDismisser], the way the app does above its
/// router. Without it the tap-outside action keeps Flutter's carve-out for
/// touch, and none of this is reachable with a finger.
Widget _host({required FocusNode fieldFocus, required VoidCallback onCancel}) => FluentApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => KeyboardDismisser(child: child!),
      home: ThemableContentDialog(
        // The pattern animates forever, so pumpAndSettle would never return.
        showBackgroundPattern: false,
        title: const Text('Edit to-do list'),
        content: TextBox(focusNode: fieldFocus, maxLines: null, minLines: 8),
        actions: [
          Button(onPressed: onCancel, child: const Text('Cancel')),
          FilledButton(onPressed: () {}, child: const Text('Save')),
        ],
      ),
    );

void main() {

  /// Presses without lifting, which is where the damage was done: the tap-outside
  /// handler runs on the pointer-*down*.
  Future<TestGesture> pressDown(WidgetTester tester, Offset at) async {
    final gesture = await tester.startGesture(at, kind: PointerDeviceKind.touch);
    await tester.pump();
    return gesture;
  }

  testWidgets('pressing a dialog action does not dismiss the keyboard first', (tester) async {
    final fieldFocus = FocusNode();
    addTearDown(fieldFocus.dispose);
    var cancelled = false;

    await tester.pumpWidget(_host(fieldFocus: fieldFocus, onCancel: () => cancelled = true));

    fieldFocus.requestFocus();
    await tester.pump();
    expect(fieldFocus.hasFocus, isTrue, reason: 'the task field starts focused, as autofocus leaves it');

    // A finger goes down on Cancel while the keyboard is still up.
    final gesture = await pressDown(tester, tester.getCenter(find.widgetWithText(Button, 'Cancel').first));

    // The press must not be spent on dropping focus: that is what dismisses the
    // keyboard and slides the dialog out from under the finger mid-press.
    expect(fieldFocus.hasFocus, isTrue, reason: 'the action row belongs to the field tap region');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(cancelled, isTrue, reason: 'the press reaches the button instead');
  });

  testWidgets('pressing the dialog body still dismisses the keyboard', (tester) async {
    final fieldFocus = FocusNode();
    addTearDown(fieldFocus.dispose);

    await tester.pumpWidget(_host(fieldFocus: fieldFocus, onCancel: () {}));

    fieldFocus.requestFocus();
    await tester.pump();
    expect(fieldFocus.hasFocus, isTrue);

    // The control: outside the field and outside the action row, a touch still
    // drops focus — so the test above is proving the tap region, not a missing
    // [KeyboardDismisser].
    final gesture = await pressDown(tester, tester.getCenter(find.text('Edit to-do list')));
    expect(fieldFocus.hasFocus, isFalse);

    await gesture.up();
    await tester.pumpAndSettle();
  });

}
