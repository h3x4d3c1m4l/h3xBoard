import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/app_settings_enums.dart';
import 'package:h3xboard/views/board_screen/components/board_scaffold.dart';

/// Stand-in for the real board: aspect-locked to the 1920×1080 canvas, exactly
/// like [BoardScreenView]'s `center`.
final Key _boardKey = UniqueKey();
final Key _barKey = UniqueKey();
final Key _otherBarKey = UniqueKey();

/// Sizes the test surface, so the scaffold really is laid out at [window] rather
/// than clamped to the 800×600 default.
void _sizeWindow(WidgetTester tester, Size window) {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host({
  required Size window,
  required BarPosition position,
  required bool inside,
  bool visible = true,
}) => FluentApp(
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
                inside: inside,
                visible: visible,
                bar: Container(key: _barKey, width: 60, height: 60, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );

void main() {
  // Windows that put the board's spare space on different axes: a wide one leaves
  // the board height-limited (spare width), a tall one leaves it width-limited
  // (spare height). An outside bar has to hug the board's real edge in both.
  const wide = Size(1600, 700);
  const tall = Size(900, 1000);

  group('BoardScaffold outside bars hug the board edge', () {
    for (final (name, window) in [('wide window', wide), ('tall window', tall)]) {
      testWidgets('$name, docked top', (tester) async {
        _sizeWindow(tester, window);
        await tester.pumpWidget(_host(window: window, position: BarPosition.top, inside: false));

        final bar = tester.getRect(find.byKey(_barKey));
        final board = tester.getRect(find.byKey(_boardKey));
        expect(board.top - bar.bottom, moreOrLessEquals(8), reason: 'gap to the board, not to the screen edge');
        expect(bar.center.dx, moreOrLessEquals(board.center.dx));
      });

      testWidgets('$name, docked left', (tester) async {
        _sizeWindow(tester, window);
        await tester.pumpWidget(_host(window: window, position: BarPosition.left, inside: false));

        final bar = tester.getRect(find.byKey(_barKey));
        final board = tester.getRect(find.byKey(_boardKey));
        expect(board.left - bar.right, moreOrLessEquals(8));
        expect(bar.center.dy, moreOrLessEquals(board.center.dy));
      });
    }
  });

  // The two rings compose: a side bar must not make the row it lives in any
  // taller than the board, or the top bar stacked above that row is pushed away
  // from the board's edge (and up against the screen's own top bar).
  testWidgets('a side bar does not push a top bar off the board edge', (tester) async {
    const window = Size(900, 1000); // board is width-limited: spare height for the gap to show up in
    _sizeWindow(tester, window);
    await tester.pumpWidget(FluentApp(
      home: SizedBox(
        width: window.width,
        height: window.height,
        child: BoardScaffold(
          center: AspectRatio(
            aspectRatio: 1920 / 1080,
            child: Container(key: _boardKey, color: Colors.white),
          ),
          bars: [
            DockedBar(
              position: BarPosition.left,
              inside: false,
              bar: Container(key: _barKey, width: 60, height: 300, color: Colors.red),
            ),
            DockedBar(
              position: BarPosition.top,
              inside: false,
              bar: Container(key: _otherBarKey, width: 300, height: 60, color: Colors.blue),
            ),
          ],
        ),
      ),
    ));

    final board = tester.getRect(find.byKey(_boardKey));
    final topBar = tester.getRect(find.byKey(_otherBarKey));
    final sideBar = tester.getRect(find.byKey(_barKey));
    expect(board.top - topBar.bottom, moreOrLessEquals(8));
    expect(board.left - sideBar.right, moreOrLessEquals(8), reason: 'and the side bar still hugs its own edge');
  });

  testWidgets('an inside bar is inset from the board edge it hugs', (tester) async {
    _sizeWindow(tester, wide);
    await tester.pumpWidget(_host(window: wide, position: BarPosition.left, inside: true));

    final bar = tester.getRect(find.byKey(_barKey));
    final board = tester.getRect(find.byKey(_boardKey));
    expect(bar.left - board.left, moreOrLessEquals(16));
  });

  testWidgets('a hidden outside bar gives its space back to the board', (tester) async {
    // A window where height is what limits the board, so the height a top-docked
    // bar hands back is height the board can actually use.
    const window = Size(1600, 700);
    _sizeWindow(tester, window);
    await tester.pumpWidget(_host(window: window, position: BarPosition.top, inside: false));
    final shown = tester.getRect(find.byKey(_boardKey));

    await tester.pumpWidget(_host(window: window, position: BarPosition.top, inside: false, visible: false));
    await tester.pumpAndSettle();
    final hidden = tester.getRect(find.byKey(_boardKey));

    expect(hidden.height, greaterThan(shown.height));
    expect(hidden.center, within(distance: 0.01, from: window.center(Offset.zero)), reason: 'stays centred');
  });
}
