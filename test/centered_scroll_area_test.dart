import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/views/login_screen/components/centered_scroll_area.dart';

const _formKey = ValueKey('form');

/// Stands in for the login form: one fixed-height block, sized per test to be
/// shorter or taller than the page it is given.
Widget _form(double height) => SizedBox(key: _formKey, width: 360, height: height);

/// A page of exactly [height] — what [ScaffoldPage] hands its content, and what
/// shrinks by the keyboard height when one opens. Kept inside the 800x600 test
/// surface, which would otherwise clamp it.
Widget _host(Widget child, {required double height, EdgeInsets padding = EdgeInsets.zero}) => FluentApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 400,
      height: height,
      child: CenteredScrollArea(padding: padding, child: child),
    ),
  ),
);

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(find.descendant(of: find.byType(CenteredScrollArea), matching: find.byType(Scrollable)))
    .position;

void main() {
  group('content that fits', () {
    testWidgets('is centered, exactly as a plain Center would', (tester) async {
      await tester.pumpWidget(_host(_form(200), height: 500));

      expect(tester.getCenter(find.byKey(_formKey)).dy, 250);
    });

    testWidgets('does not scroll', (tester) async {
      await tester.pumpWidget(_host(_form(200), height: 500));

      expect(_position(tester).maxScrollExtent, 0);
    });

    testWidgets('does not scroll by its own padding either', (tester) async {
      // The trap the widget exists to close: padding that is not taken off the
      // minimum height makes the content box `viewport + padding.vertical` tall,
      // so every page becomes scrollable by the gap it just added.
      await tester.pumpWidget(_host(_form(200), height: 500, padding: const EdgeInsets.symmetric(vertical: 12)));

      expect(_position(tester).maxScrollExtent, 0);
      expect(tester.getCenter(find.byKey(_formKey)).dy, 250);
    });
  });

  group('content that does not fit', () {
    testWidgets('scrolls instead of overflowing', (tester) async {
      await tester.pumpWidget(_host(_form(700), height: 500));

      expect(tester.takeException(), isNull);
      expect(_position(tester).maxScrollExtent, 200);
    });

    testWidgets('can be scrolled to its very end', (tester) async {
      await tester.pumpWidget(_host(_form(700), height: 500));

      // The form's bottom starts 200px below the page; scrolling that far must
      // bring it to rest on the bottom edge — that is the sign-in button
      // becoming reachable under the keyboard.
      expect(tester.getRect(find.byKey(_formKey)).bottom, 700);
      await tester.drag(find.byType(CenteredScrollArea), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(_formKey)).bottom, 500);
    });

    testWidgets('keeps its end gaps clear of the content', (tester) async {
      await tester.pumpWidget(_host(_form(700), height: 500, padding: const EdgeInsets.symmetric(vertical: 12)));

      expect(_position(tester).maxScrollExtent, 224);
    });
  });

  testWidgets('a shrinking page starts scrolling rather than overflowing', (tester) async {
    // The keyboard opening on a tablet: ScaffoldPage takes its height off the
    // content box, and a form that was centered a frame ago no longer fits.
    await tester.pumpWidget(_host(_form(400), height: 500));
    expect(_position(tester).maxScrollExtent, 0);

    await tester.pumpWidget(_host(_form(400), height: 300));

    expect(tester.takeException(), isNull);
    expect(_position(tester).maxScrollExtent, 100);
  });
}
