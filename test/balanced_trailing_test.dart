import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/app_settings_enums.dart';
import 'package:h3xboard/views/board_screen/components/balanced_trailing.dart';
import 'package:h3xboard/views/board_screen/components/board_scaffold.dart';

/// Guards the one invariant [BalancedTrailing] exists for: a control hung off the
/// end of a docked bar must not move the bar. The scaffold centres whatever it is
/// handed, so a plain Row would silently slide the bar left by half the trailing
/// control's width — a regression nothing else in the suite would notice, since
/// the layout is still perfectly valid, just wrong.
final Key _boardKey = UniqueKey();
final Key _barKey = UniqueKey();
final Key _trailingKey = UniqueKey();

/// Sizes the test surface so the scaffold is laid out at [window] rather than
/// clamped to the 800×600 default.
void _sizeWindow(WidgetTester tester, Size window) {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host({required Size window, required BarPosition position}) => FluentApp(
      home: Center(
        child: SizedBox(
          width: window.width,
          height: window.height,
          child: BoardScaffold(
            center: AspectRatio(
              aspectRatio: 1920 / 1080,
              child: Container(key: _boardKey, color: Colors.white),
            ),
            bars: [
              DockedBar(
                position: position,
                inside: false,
                bar: BalancedTrailing(
                  direction: position.axis,
                  trailing: Container(key: _trailingKey, width: 36, height: 36, color: Colors.blue),
                  child: Container(key: _barKey, width: 300, height: 52, color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );

void main() {
  // Windows that put the board's spare space on different axes, matching
  // board_scaffold_test: the bar has to stay centred in both.
  const wide = Size(1600, 700);
  const tall = Size(900, 1000);

  group('a trailing control does not move the bar off centre', () {
    for (final (name, window) in [('wide window', wide), ('tall window', tall)]) {
      testWidgets('$name, docked top', (tester) async {
        _sizeWindow(tester, window);
        await tester.pumpWidget(_host(window: window, position: BarPosition.top));

        final bar = tester.getRect(find.byKey(_barKey));
        final board = tester.getRect(find.byKey(_boardKey));
        expect(bar.center.dx, moreOrLessEquals(board.center.dx));
      });

      testWidgets('$name, docked left', (tester) async {
        _sizeWindow(tester, window);
        await tester.pumpWidget(_host(window: window, position: BarPosition.left));

        final bar = tester.getRect(find.byKey(_barKey));
        final board = tester.getRect(find.byKey(_boardKey));
        expect(bar.center.dy, moreOrLessEquals(board.center.dy));
      });
    }
  });

  testWidgets('the trailing control sits after the bar, one gap away', (tester) async {
    _sizeWindow(tester, wide);
    await tester.pumpWidget(_host(window: wide, position: BarPosition.top));

    // Two copies: the invisible counterweight (first in tree order) and the real
    // one. The counterweight is what buys the centring asserted above.
    expect(find.byKey(_trailingKey), findsNWidgets(2));

    final bar = tester.getRect(find.byKey(_barKey));
    final counterweight = tester.getRect(find.byKey(_trailingKey).at(0));
    final trailing = tester.getRect(find.byKey(_trailingKey).at(1));

    expect(trailing.left - bar.right, moreOrLessEquals(8));
    expect(bar.left - counterweight.right, moreOrLessEquals(8));
    expect(trailing.center.dy, moreOrLessEquals(bar.center.dy), reason: 'centred against the bar');
  });

  testWidgets('the counterweight is invisible to pointers and semantics', (tester) async {
    _sizeWindow(tester, wide);
    var taps = 0;
    await tester.pumpWidget(FluentApp(
      home: Center(
        child: BalancedTrailing(
          trailing: GestureDetector(
            key: _trailingKey,
            onTap: () => taps++,
            child: Container(width: 36, height: 36, color: Colors.blue),
          ),
          child: Container(key: _barKey, width: 300, height: 52, color: Colors.red),
        ),
      ),
    ));

    await tester.tap(find.byKey(_trailingKey).at(0), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0, reason: 'the counterweight must not be tappable');

    await tester.tap(find.byKey(_trailingKey).at(1));
    await tester.pump();
    expect(taps, 1);
  });
}
