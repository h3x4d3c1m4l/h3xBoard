import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/keyboard_dismisser.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _outside = Key('outside');

Widget _host(Widget child) => FluentApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// A field with something tappable next to it. The neighbour is a [ColoredBox]
/// rather than a bare [SizedBox] because only an opaque box answers the hit test,
/// and a tap that hits nothing never reaches the tap-region surface at all.
Widget _fieldAndNeighbour(
  FocusNode focusNode, {
  void Function(PointerDownEvent)? onTapOutside,
  bool obscureText = false,
}) => Column(
  children: [
    ContinuousTextBox(focusNode: focusNode, onTapOutside: onTapOutside, obscureText: obscureText),
    const ColoredBox(
      color: Color(0xFF000000),
      child: SizedBox(key: _outside, width: 200, height: 200),
    ),
  ],
);

/// The behaviour under test exists only for a finger on native Android/iOS —
/// Flutter's default action already unfocuses for a mouse, and on web even for
/// touch. Both conditions hold here without any setup: `flutter test` reports
/// `TargetPlatform.android` (foundation/_platform_io.dart:29-34 keys off the
/// FLUTTER_TEST environment variable) and `WidgetTester` taps with
/// [PointerDeviceKind.touch] by default. The `withoutDismisser` case below is
/// what actually pins that, so this file fails loudly if either ever changes.
void main() {
  testWidgets('a touch outside the field drops focus', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(_host(KeyboardDismisser(child: _fieldAndNeighbour(focusNode))));
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue, reason: 'the field should start focused');

    await tester.tapAt(tester.getCenter(find.byKey(_outside)), kind: PointerDeviceKind.touch);
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('without the dismisser the keyboard would stay up', (tester) async {
    // The negative case: this is Flutter's stock behaviour on a phone, and it is
    // what makes the test above a test of *our* widget rather than of the default.
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(_host(_fieldAndNeighbour(focusNode)));
    focusNode.requestFocus();
    await tester.pump();

    await tester.tapAt(tester.getCenter(find.byKey(_outside)), kind: PointerDeviceKind.touch);
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('a field with its own onTapOutside keeps focus', (tester) async {
    // The on-board label editor passes an empty callback on purpose so tapping
    // its style bar keeps the caret and the keyboard. Handling it must still win.
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var taps = 0;

    await tester.pumpWidget(
      _host(KeyboardDismisser(child: _fieldAndNeighbour(focusNode, onTapOutside: (_) => taps++))),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.tapAt(tester.getCenter(find.byKey(_outside)), kind: PointerDeviceKind.touch);
    await tester.pump();

    expect(taps, 1, reason: 'the field should have handled the tap itself');
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('tapping the field\'s own suffix is not "outside"', (tester) async {
    // Every text field shares one tap-region group, and fluent's TextBox puts its
    // prefix and suffix inside it. So the password eye — the login screen's, here —
    // toggles without yanking the keyboard away mid-entry.
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(KeyboardDismisser(child: _fieldAndNeighbour(focusNode, obscureText: true))),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.tap(find.byIcon(LucideIcons.eye), kind: PointerDeviceKind.touch);
    // Long enough for fluent's HoverButton to retire its 100ms press-effect timer.
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget, reason: 'the toggle should have fired');
    expect(focusNode.hasFocus, isTrue);
  });
}
