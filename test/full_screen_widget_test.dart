import 'dart:async';

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
    await tester.pumpWidget(FluentApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MirroredFullScreenWidget(boardWidget: _boardWidget),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bring your gym kit'), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsNothing, reason: 'only the presenter can leave the mode');
    final ignoring = tester.widget<IgnorePointer>(
      find.descendant(of: find.byType(FullScreenWidgetView), matching: find.byType(IgnorePointer)),
    );
    expect(ignoring.ignoring, isTrue);
  });

  testWidgets('the mirror drops the widget once it has faded out', (tester) async {
    await tester.pumpWidget(FluentApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MirroredFullScreenWidget(boardWidget: _boardWidget),
    ));
    await tester.pumpAndSettle();

    await tester.pumpWidget(FluentApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MirroredFullScreenWidget(boardWidget: null),
    ));
    await tester.pump();
    expect(find.text('Bring your gym kit'), findsOneWidget, reason: 'still fading out');

    await tester.pumpAndSettle();
    expect(find.byType(FullScreenWidgetView), findsNothing);
  });

}
