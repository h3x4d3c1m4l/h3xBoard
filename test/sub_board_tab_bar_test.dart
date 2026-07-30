import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/theme/theme.dart';
import 'package:h3xboard/views/board_screen/components/toolbars/sub_board_tab_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Board _board(String id, String title) => Board(
      id: id,
      title: title,
      backgroundColor: Colors.white,
      isChalkboard: false,
      linePattern: BoardLinePattern.none,
      lineSpacing: 64,
      lineColor: Colors.grey,
    );

/// Renders the tab bar under the real app theme — the theme is what supplies the
/// trailing buttons' padding, so a stock one would measure the wrong thing.
Widget _host(List<Board> boards, {required double width}) => FluentApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(
        child: SizedBox(
          width: width,
          child: SubBoardTabBar(
            subBoards: boards,
            activeSubBoardId: boards.first.id,
            onSwitchSubBoard: (_) {},
            onAddSubBoard: () {},
            onRemoveSubBoard: (_) {},
            onRenameSubBoard: (_, _) {},
          ),
        ),
      ),
    );

void main() {
  group('SubBoardTabBar trailing buttons', () {
    // The overflow math in `_split` budgets a fixed width per trailing button to
    // decide how many tabs fit. Nothing at compile time ties that number to the
    // button that renders, so restyling the buttons could silently mis-collapse
    // tabs. Measure the real thing and hold the two together.
    testWidgets('render at exactly the width the overflow math budgets for', (tester) async {
      await tester.pumpWidget(_host([_board('a', 'Board 1'), _board('b', 'Board 2')], width: 800));

      for (final icon in [LucideIcons.plus, LucideIcons.pencil, LucideIcons.trash2]) {
        final button = find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)).first;
        expect(
          tester.getSize(button).width,
          SubBoardTabBar.trailingButtonWidth,
          reason: 'the $icon button must match SubBoardTabBar.trailingButtonWidth',
        );
      }
    });

    testWidgets('are square, so the bar reads as one strip', (tester) async {
      await tester.pumpWidget(_host([_board('a', 'Board 1')], width: 800));

      final button = find.ancestor(of: find.byIcon(LucideIcons.plus), matching: find.byType(IconButton)).first;
      final size = tester.getSize(button);
      expect(size.width, size.height);
    });
  });

  group('SubBoardTabBar overflow', () {
    testWidgets('keeps every tab visible when they all fit', (tester) async {
      await tester.pumpWidget(_host([_board('a', 'Board 1'), _board('b', 'Board 2')], width: 800));

      expect(find.text('Board 1'), findsOneWidget);
      expect(find.text('Board 2'), findsOneWidget);
      expect(find.byIcon(LucideIcons.ellipsis), findsNothing);
    });

    testWidgets('collapses the overflow behind a more button, keeping the active tab', (tester) async {
      final boards = [for (var i = 1; i <= 8; i++) _board('b$i', 'Board $i')];
      await tester.pumpWidget(_host(boards, width: 320));

      // The active tab never hides, and the trailing controls stay put — the
      // whole point of reserving their width in the budget.
      expect(find.text('Board 1'), findsOneWidget);
      expect(find.byIcon(LucideIcons.ellipsis), findsOneWidget);
      expect(find.byIcon(LucideIcons.plus), findsOneWidget);
      expect(find.byIcon(LucideIcons.pencil), findsOneWidget);
      expect(find.byIcon(LucideIcons.trash2), findsOneWidget);

      // Something actually overflowed, and the row still fits its 320px slot.
      expect(find.text('Board 8'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
