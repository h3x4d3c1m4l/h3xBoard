import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/views/board_screen/components/balanced_trailing.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/bar_scroll_area.dart';

const _fadeColor = Color(0xFFEAE9E6);

/// Stands in for a bar's content: fixed-size blocks laid out the way the real
/// bars are — `mainAxisSize: MainAxisSize.min`.
Widget _content({required int count, Axis direction = Axis.horizontal}) => Flex(
  direction: direction,
  mainAxisSize: MainAxisSize.min,
  children: [for (var i = 0; i < count; i++) SizedBox(key: ValueKey(i), width: 100, height: 44)],
);

/// The bar's own relaxed clip, told apart from the framework's many [ClipRect]s.
Finder get _barClip => find.byWidgetPredicate(
  (w) => w is ClipRect && w.clipper is RelaxedCrossAxisClipper,
);

Widget _host(Widget child, {double width = 600}) => FluentApp(
  home: Center(child: SizedBox(width: width, child: Center(child: child))),
);

void main() {
  group('the relaxed clipper', () {
    test('keeps the scroll axis exactly and relaxes the cross axis', () {
      const size = Size(400, 48);

      // A horizontal bar: the ends must be cut, the sides must not — that is
      // where the active swatch's 16px glow lands.
      const horizontal = RelaxedCrossAxisClipper(scrollAxis: Axis.horizontal);
      expect(horizontal.getClip(size), const Rect.fromLTRB(0, -kBarClipBleed, 400, 48 + kBarClipBleed));

      const vertical = RelaxedCrossAxisClipper(scrollAxis: Axis.vertical);
      expect(vertical.getClip(size), const Rect.fromLTRB(-kBarClipBleed, 0, 400 + kBarClipBleed, 48));
    });

    test('bleeds far enough for the widest thing a bar paints outside itself', () {
      // The active colour swatch is a 44px circle in a 48px box with a
      // `blurRadius: 16` glow, so the glow reaches 14px past the box.
      expect(kBarClipBleed, greaterThanOrEqualTo(16));
    });
  });

  group('a bar that fits', () {
    testWidgets('keeps its own size instead of filling the room offered', (tester) async {
      await tester.pumpWidget(_host(BarScrollArea(child: _content(count: 3))));
      await tester.pumpAndSettle();

      // 3 x 100 in 600px of room: the viewport must shrink-wrap, or the bar's
      // surface would stretch across the whole edge and stop being a pill.
      expect(tester.getSize(find.byType(BarScrollArea)).width, 300);
    });

    testWidgets('clips nothing at all, so glows and shadows survive', (tester) async {
      await tester.pumpWidget(_host(BarScrollArea(fadeColor: _fadeColor, child: _content(count: 3))));
      await tester.pumpAndSettle();

      expect(_barClip, findsNothing, reason: 'a bar with nothing to hide has earned no clip');
      expect(find.byKey(kBarFadeLeadingKey), findsNothing);
      expect(find.byKey(kBarFadeTrailingKey), findsNothing);
    });
  });

  group('a bar that does not fit', () {
    testWidgets('clamps to the room available rather than overflowing', (tester) async {
      await tester.pumpWidget(_host(BarScrollArea(child: _content(count: 8))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'this is the RenderFlex overflow being fixed');
      expect(tester.getSize(find.byType(BarScrollArea)).width, 600);
    });

    testWidgets('clips its ends but not its sides', (tester) async {
      await tester.pumpWidget(_host(BarScrollArea(child: _content(count: 8))));
      await tester.pumpAndSettle();

      expect(_barClip, findsOneWidget);
      final clipper = tester.widget<ClipRect>(_barClip).clipper! as RelaxedCrossAxisClipper;
      expect(clipper.scrollAxis, Axis.horizontal);
    });

    testWidgets('fades the end it is scrolled away from', (tester) async {
      await tester.pumpWidget(_host(BarScrollArea(fadeColor: _fadeColor, child: _content(count: 8))));
      await tester.pumpAndSettle();

      // Resting at the start: nothing is hidden behind the leading edge yet.
      expect(tester.widget<Opacity>(find.descendant(
        of: find.byKey(kBarFadeLeadingKey), matching: find.byType(Opacity))).opacity, 0);
      expect(tester.widget<Opacity>(find.descendant(
        of: find.byKey(kBarFadeTrailingKey), matching: find.byType(Opacity))).opacity, 1);
    });

    testWidgets('a bar with no surface of its own scrolls without a fade', (tester) async {
      await tester.pumpWidget(_host(BarScrollArea(child: _content(count: 8))));
      await tester.pumpAndSettle();

      expect(_barClip, findsOneWidget, reason: 'it still scrolls');
      expect(find.byKey(kBarFadeTrailingKey), findsNothing,
          reason: 'no honest colour to fade into, so no fade rather than a wrong one');
    });

    testWidgets('lets the far end be reached by scrolling', (tester) async {
      await tester.pumpWidget(_host(BarScrollArea(child: _content(count: 8))));
      await tester.pumpAndSettle();

      final last = find.byKey(const ValueKey(7));
      expect(tester.getRect(last).left, greaterThan(600), reason: 'starts out past the edge');

      await tester.drag(find.byType(BarScrollArea), const Offset(-400, 0));
      await tester.pumpAndSettle();

      final viewport = tester.getRect(find.byType(BarScrollArea));
      expect(tester.getRect(last).right, lessThanOrEqualTo(viewport.right + precisionErrorTolerance));
    });

    testWidgets('scrolls along its own axis when the bar is docked vertically', (tester) async {
      await tester.pumpWidget(FluentApp(
        home: Center(child: SizedBox(
          height: 300,
          child: Center(child: BarScrollArea(direction: Axis.vertical, child: _content(count: 8, direction: Axis.vertical))),
        )),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(BarScrollArea)).height, 300);
      expect((tester.widget<ClipRect>(_barClip).clipper! as RelaxedCrossAxisClipper).scrollAxis, Axis.vertical);
    });
  });

  testWidgets('a bar hung with BalancedTrailing stays centred once it scrolls', (tester) async {
    const trailingKey = ValueKey('trailing');
    await tester.pumpWidget(FluentApp(
      home: Center(child: SizedBox(
        width: 600,
        child: BalancedTrailing(
          trailing: const SizedBox(key: trailingKey, width: 36, height: 36),
          child: BarScrollArea(child: _content(count: 8)),
        ),
      )),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'the Flex must not overflow either');

    final row = tester.getRect(find.byType(BalancedTrailing));
    final bar = tester.getRect(find.byType(BarScrollArea));
    expect(bar.center.dx, moreOrLessEquals(row.center.dx),
        reason: 'the counterweight has to keep working when the bar takes the remaining width');
  });
}
