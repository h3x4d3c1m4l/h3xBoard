import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/board_mirror_scope.dart';
import 'package:h3xboard/views/board_screen/components/read_only_board.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_style.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/components/editor_pane.dart';
import 'package:h3xboard/views/board_screen/components/widgets/traffic_light_widget.dart';

const _board = Board(
  id: 'b1',
  title: 'Lesson',
  backgroundColor: Color(0xFFFFFFFF),
  isChalkboard: false,
  linePattern: BoardLinePattern.none,
  lineSpacing: 40,
  lineColor: Color(0xFFDDDDDD),
);

Widget _host(Widget child) => FluentApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: FluentThemeData(accentColor: const Color(0xFF00FF80).toAccentColor()),
      home: child,
    );

void main() {
  // google_fonts in a widget test starts an async load that outlives the test.
  setUpAll(() => CodePlaygroundStyle.debugFontFamily = 'Roboto');

  late DrawingController drawing;

  setUp(() => drawing = DrawingController());
  tearDown(() => drawing.dispose());

  Future<void> pumpBoard(WidgetTester tester, List<BoardWidget> widgets) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      ReadOnlyBoard(board: _board, widgets: widgets, drawingController: drawing),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  BoardWidget at(String id, double x, double y) => BoardWidget(
        id: id,
        config: const TrafficLightConfig(),
        x: x,
        y: y,
      );

  group('ReadOnlyBoard', () {
    testWidgets('widgets keep their place on the canvas', (tester) async {
      // The widget layer gained a nested stack so it could carry the mirror
      // scope, and everything in it is positioned in canvas space — so its size
      // now comes from the constraints rather than from a child. Placement is
      // the thing that would quietly go wrong if that ever stopped holding.
      await pumpBoard(tester, [at('left', 300, 540), at('right', 1600, 540)]);
      expect(tester.takeException(), isNull);

      final lights = find.byType(TrafficLightWidget);
      expect(lights, findsNWidgets(2));

      final first = tester.getRect(lights.at(0));
      final second = tester.getRect(lights.at(1));
      expect(first.width, greaterThan(0), reason: 'a collapsed stack renders nothing');
      expect(first.center.dx, lessThan(second.center.dx), reason: 'x must still order them');
      expect(first.center.dy, moreOrLessEquals(second.center.dy, epsilon: 1));
    });

    testWidgets('widgets on it know they are a mirror', (tester) async {
      await pumpBoard(tester, [
        BoardWidget(id: 'code', config: const CodePlaygroundConfig(), x: 960, y: 540),
      ]);

      // The scope is the only signal a widget gets: ReadOnlyBoard hands every one
      // of them the same discard-everything callback the widget catalog uses.
      for (final pane in tester.widgetList<EditorPane>(find.byType(EditorPane))) {
        expect(pane.readOnly, isTrue);
      }

      final context = tester.element(find.byType(EditorPane).first);
      expect(BoardMirrorScope.isMirror(context), isTrue);
    });
  });
}
