import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/views/components/scroll_shadow.dart';

/// The two edge gradients, in the order [ScrollShadow] stacks them: top first.
List<double> _opacities(WidgetTester tester) => tester
    .widgetList<Opacity>(find.descendant(of: find.byType(ScrollShadow), matching: find.byType(Opacity)))
    .map((o) => o.opacity)
    .toList();

double _top(WidgetTester tester) => _opacities(tester)[0];
double _bottom(WidgetTester tester) => _opacities(tester)[1];

/// The content needs a width of its own: a [Stack] hands its non-positioned
/// child *loose* constraints, so the scroll view shrink-wraps sideways and a
/// zero-width child would leave nothing to drag.
Widget _host(double contentHeight) => FluentApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      height: 500,
      width: 400,
      child: ScrollShadow(
        child: SingleChildScrollView(child: SizedBox(height: contentHeight, width: 400)),
      ),
    ),
  ),
);

void main() {
  testWidgets('lights the bottom edge as soon as there is something below it', (tester) async {
    await tester.pumpWidget(_host(900));
    await tester.pumpAndSettle();

    // No drag has happened: the metrics alone have to be enough, or the hint
    // only shows up once the user has already found the scroll.
    expect(_bottom(tester), 1);
    expect(_top(tester), 0);
  });

  testWidgets('lights the top edge once content is scrolled past it', (tester) async {
    await tester.pumpWidget(_host(900));
    await tester.drag(find.byType(ScrollShadow), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(_top(tester), 1);
    expect(_bottom(tester), 1);
  });

  testWidgets('puts a lit edge out when the content shrinks back to fitting', (tester) async {
    // The login form does exactly this: validation errors make it outgrow the
    // page, and fixing them makes it fit again. A shadow lit by the drag in
    // between used to stay lit, with nothing behind it to scroll to.
    await tester.pumpWidget(_host(900));
    await tester.drag(find.byType(ScrollShadow), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(_bottom(tester), 1);

    await tester.pumpWidget(_host(300));
    await tester.pumpAndSettle();

    expect(_bottom(tester), 0);
    expect(_top(tester), 0);
  });

  testWidgets('lights up again when a shrinking viewport makes content overflow', (tester) async {
    // The other half of the same story: the keyboard opening takes the room
    // away rather than the content taking more.
    await tester.pumpWidget(_host(300));
    await tester.pumpAndSettle();
    expect(_bottom(tester), 0);

    await tester.pumpWidget(_host(700));
    await tester.pumpAndSettle();

    expect(_bottom(tester), 1);
  });
}
