import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/theme/theme.dart';
import 'package:h3xboard/views/board_screen/components/widgets/full_screen_widget_view.dart';
import 'package:h3xboard/views/board_screen/components/widgets/memo_note_widget.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A memo note: it draws its text with no ticker of its own, so
/// [WidgetTester.pumpAndSettle] actually settles.
const BoardWidgetConfig _config = BoardWidgetConfig.memoNote(text: 'Bring your gym kit');

const BoardWidget _boardWidget = BoardWidget(id: 'w1', config: _config, x: 100, y: 100);

/// Bare app shell for the mirror-side widgets, which need no navigator.
Widget _host(Widget child) => FluentApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

Widget _app({required GlobalKey<NavigatorState> navigatorKey}) => FluentApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorKey: navigatorKey,
      home: const ScaffoldPage(content: Center(child: Text('the board'))),
    );

/// Opens the widget the way the board's context menu does.
Future<void> _showFullScreen(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigatorKey, {
  ValueChanged<BoardWidgetConfig>? onConfigChanged,
}) async {
  final context = navigatorKey.currentContext!;
  unawaited(showAppDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (routeContext) => FullScreenWidgetView(
      config: _config,
      onConfigChanged: onConfigChanged ?? (_) {},
      onClose: () => Navigator.of(routeContext).pop(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {

  group('a widget shown full screen', () {

    testWidgets('fills the screen with the widget, far larger than it is on the board', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey: navigatorKey));
      await _showFullScreen(tester, navigatorKey);

      expect(find.text('Bring your gym kit'), findsOneWidget);
      // getRect, not getSize: the widget is *laid out* at its natural size and
      // scaled by the FittedBox's transform, which only the global rect sees.
      final view = tester.getRect(find.byType(FullScreenWidgetView));
      final note = tester.getRect(find.byType(MemoNoteWidget));
      expect(note.width, greaterThan(MemoNoteWidget.naturalSize.width), reason: 'blown up past its board size');
      expect(note.width, closeTo(note.height, 0.5), reason: 'a memo note stays square');
      expect(view.inflate(0.5).contains(note.topLeft), isTrue, reason: 'stays on screen');
      expect(view.inflate(0.5).contains(note.bottomRight), isTrue, reason: 'stays on screen');
    });

    testWidgets('the close button leaves the mode', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey: navigatorKey));
      await _showFullScreen(tester, navigatorKey);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenWidgetView), findsNothing);
    });

    testWidgets('Escape leaves the mode', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey: navigatorKey));
      await _showFullScreen(tester, navigatorKey);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenWidgetView), findsNothing);
    });

    testWidgets('tapping beside the widget leaves the mode', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigatorKey: navigatorKey));
      await _showFullScreen(tester, navigatorKey);

      // The bottom-left corner: outside the centred widget, on the barrier.
      // Nothing in the view may be opaque out here, or the barrier never sees it.
      await tester.tapAt(tester.getBottomLeft(find.byType(FullScreenWidgetView)) + const Offset(8, -8));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenWidgetView), findsNothing);
    });

  });

  testWidgets('a mirrored full-screen widget takes no input of its own', (tester) async {
    await tester.pumpWidget(_host(
      const MirroredFullScreenWidget(
        boardWidget: _boardWidget,
        animation: AlwaysStoppedAnimation(1),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bring your gym kit'), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsNothing, reason: 'only the presenter can leave the mode');
    final ignoring = tester.widget<IgnorePointer>(
      find.descendant(of: find.byType(FullScreenWidgetView), matching: find.byType(IgnorePointer)),
    );
    expect(ignoring.ignoring, isTrue);
  });

  testWidgets('the flight starts where the widget sits on the board', (tester) async {
    const origin = Rect.fromLTWH(120, 60, 200, 200);
    await tester.pumpWidget(_host(
      Stack(children: [
        const FullScreenWidgetView(
          config: _config,
          animation: AlwaysStoppedAnimation(0),
          originOf: _staticOrigin,
        ),
      ]),
    ));
    await tester.pumpAndSettle();

    // The whole design rests on this: at the start of the flight the blown-up
    // copy is exactly the board's copy, which is what lets the board hide its
    // own without a seam.
    final rect = tester.getRect(find.byType(MemoNoteWidget));
    expect(rect.left, moreOrLessEquals(origin.left, epsilon: 0.5));
    expect(rect.top, moreOrLessEquals(origin.top, epsilon: 0.5));
    expect(rect.width, moreOrLessEquals(origin.width, epsilon: 0.5));
    expect(rect.height, moreOrLessEquals(origin.height, epsilon: 0.5));
  });

  testWidgets('a rotation of several turns flies from the same place as one', (tester) async {
    Future<Rect> rectFor(double rotation) async {
      await tester.pumpWidget(_host(
        Stack(children: [
          FullScreenWidgetView(
            config: _config,
            animation: const AlwaysStoppedAnimation(0.5),
            originOf: () => (rect: const Rect.fromLTWH(120, 60, 200, 200), rotation: rotation),
          ),
        ]),
      ));
      await tester.pumpAndSettle();
      return tester.getRect(find.byType(MemoNoteWidget));
    }

    // Rotation accumulates raw on the board, so a widget can carry several
    // revolutions; unwinding them all would spend the flight spinning.
    final once = await rectFor(0.3);
    final wound = await rectFor(0.3 + 4 * math.pi);
    expect(wound.left, moreOrLessEquals(once.left, epsilon: 0.5));
    expect(wound.top, moreOrLessEquals(once.top, epsilon: 0.5));
  });

  group('the mirror', () {

    Widget mirror({BoardWidget? fullScreen}) => _host(
          MirroredBoardWidgets(widgets: const [_boardWidget], fullScreenWidget: fullScreen),
        );

    testWidgets('drops the blown-up copy once it has flown home', (tester) async {
      await tester.pumpWidget(mirror(fullScreen: _boardWidget));
      await tester.pumpAndSettle();

      await tester.pumpWidget(mirror());
      await tester.pump();
      expect(find.byType(FullScreenWidgetView), findsOneWidget, reason: 'still flying home');

      await tester.pumpAndSettle();
      expect(find.byType(FullScreenWidgetView), findsNothing);
    });

    testWidgets('hides the board copy for exactly as long as the flight lasts', (tester) async {
      Opacity boardCopy() => tester.widget<Opacity>(
            find.ancestor(of: find.byType(MemoNoteWidget).first, matching: find.byType(Opacity)).first,
          );

      await tester.pumpWidget(mirror());
      await tester.pumpAndSettle();
      expect(boardCopy().opacity, 1);

      await tester.pumpWidget(mirror(fullScreen: _boardWidget));
      await tester.pumpAndSettle();
      expect(boardCopy().opacity, 0, reason: 'the widget must never be on screen twice');

      // The mode is over, but the copy is still on its way back — un-hiding here
      // would put the widget on the board while it is still in the air.
      await tester.pumpWidget(mirror());
      await tester.pump();
      expect(boardCopy().opacity, 0);

      await tester.pumpAndSettle();
      expect(boardCopy().opacity, 1);
    });

  });

}

({Rect rect, double rotation})? _staticOrigin() => (rect: const Rect.fromLTWH(120, 60, 200, 200), rotation: 0);
