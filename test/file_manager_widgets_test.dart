import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_breadcrumb.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_details.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_entry.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_list.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_prompts.dart';

/// The file manager's two panes and its breadcrumb, covered where they can be
/// covered without a server: rendering, and which entry a control reports.
///
/// The parts that talk to the API are deliberately not here — the dialog owns
/// every mutation precisely so these three stay pure enough to test.
void main() {
  final fileService = H3xBoardFileService.create('http://localhost', CookieStore());

  FileSummary file(String name, {String type = 'application/pdf', int size = 2048}) => FileSummary(
        id: 'id-$name',
        path: 'docs',
        fileName: name,
        contentType: type,
        sizeBytes: size,
        createdAt: DateTime.utc(2026, 8, 20, 14, 30),
        updatedAt: DateTime.utc(2026, 8, 20, 14, 30),
      );

  Widget wrap(Widget child) => FluentApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScaffoldPage(content: SizedBox(width: 600, height: 500, child: child)),
      );

  group('FileManagerBreadcrumb', () {
    testWidgets('the root is a label, not a dead link', (tester) async {
      // A disabled HyperlinkButton is painted in fluent's disabled grey, which is
      // all but invisible on the dialog's patterned surface.
      await tester.pumpWidget(wrap(FileManagerBreadcrumb(path: '', onNavigate: (_) {})));

      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(HyperlinkButton), findsNothing);
    });

    testWidgets('a nested path walks back to the folder that was clicked', (tester) async {
      String? navigated;
      await tester.pumpWidget(wrap(
        FileManagerBreadcrumb(path: 'images/holiday/2026', onNavigate: (path) => navigated = path),
      ));

      expect(find.text('images'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);

      // The crumb carries the path it stands for, not just its own name — a
      // breadcrumb that navigated to "holiday" would land in the wrong tree.
      await tester.tap(find.text('holiday'));
      await tester.pumpAndSettle();
      expect(navigated, 'images/holiday');
    });

    testWidgets('the last crumb is where you already are, so it is a label', (tester) async {
      await tester.pumpWidget(wrap(FileManagerBreadcrumb(path: 'images', onNavigate: (_) {})));

      // Only "Home" is still somewhere to go.
      final buttons = tester.widgetList<HyperlinkButton>(find.byType(HyperlinkButton)).toList();
      expect(buttons, hasLength(1));
      expect(buttons.single.onPressed, isNotNull);
      expect(find.text('images'), findsOneWidget);
    });

    testWidgets('the current crumb reads in the body colour, not the disabled one', (tester) async {
      await tester.pumpWidget(wrap(FileManagerBreadcrumb(path: 'images', onNavigate: (_) {})));

      final style = tester.widget<Text>(find.text('images')).style;
      final theme = FluentThemeData();
      expect(style?.color, isNot(theme.resources.textFillColorDisabled));
      expect(style?.fontWeight, theme.typography.bodyStrong?.fontWeight);
    });
  });

  group('FileManagerList', () {
    final entries = <FileManagerEntry>[
      const FolderEntry('docs/archive'),
      FileEntry(file('notes.pdf')),
      FileEntry(file('report.pdf')),
    ];

    Widget buildList({
      Set<String> selected = const {},
      void Function(FileManagerEntry)? onPressed,
      void Function(FileManagerEntry)? onChecked,
      void Function(FileManagerEntry, FileManagerRowAction)? onAction,
      ValueChanged<bool>? onSelectAll,
      bool enabled = true,
    }) =>
        wrap(FileManagerList(
          entries: entries,
          selectedIds: selected,
          enabled: enabled,
          onRowPressed: onPressed ?? (_) {},
          onRowChecked: onChecked ?? (_) {},
          onRowAction: onAction ?? (_, _) {},
          onSelectAllChanged: onSelectAll,
        ));

    testWidgets('lists the folder and its files', (tester) async {
      await tester.pumpWidget(buildList());

      expect(find.text('archive'), findsOneWidget);
      expect(find.text('notes.pdf'), findsOneWidget);
      expect(find.text('2 KB'), findsNWidgets(2));
    });

    testWidgets('a row reports itself, not its index', (tester) async {
      FileManagerEntry? pressed;
      await tester.pumpWidget(buildList(onPressed: (entry) => pressed = entry));

      await tester.tap(find.text('report.pdf'));
      await tester.pumpAndSettle();
      expect(pressed?.name, 'report.pdf');
    });

    testWidgets('the checkbox toggles instead of navigating', (tester) async {
      FileManagerEntry? checked;
      FileManagerEntry? pressed;
      await tester.pumpWidget(buildList(
        onChecked: (entry) => checked = entry,
        onPressed: (entry) => pressed = entry,
      ));

      // The first checkbox is the header's "select all"; the folder's is next.
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      expect(checked, isA<FolderEntry>());
      expect(pressed, isNull, reason: 'checking a row must not also open it');
    });

    testWidgets('the header checkbox reads as partial while some rows are selected', (tester) async {
      await tester.pumpWidget(buildList(selected: {'id-notes.pdf'}, onSelectAll: (_) {}));

      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).checked, isNull);
      expect(find.text('1 item selected'), findsOneWidget);
    });

    testWidgets('every row selected checks the header outright', (tester) async {
      await tester.pumpWidget(buildList(
        selected: entries.map((e) => e.selectionId).toSet(),
        onSelectAll: (_) {},
      ));

      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).checked, isTrue);
    });

    testWidgets('a resting row fades from the hover colour, not from transparent black', (tester) async {
      // Colors.transparent is transparent *black*, so an AnimatedContainer
      // lerping to a light hover fill travels through dark greys and flashes
      // once. The resting colour must be the hover colour at zero alpha.
      await tester.pumpWidget(buildList());

      final resting = _rowFill(tester, 'notes.pdf');

      expect(resting.a, 0);
      final hover = FluentThemeData().resources.subtleFillColorSecondary;
      expect(resting.r, hover.r);
      expect(resting.g, hover.g);
      expect(resting.b, hover.b);
    });

    testWidgets('a selected row draws its name on the accent, in the paired foreground', (tester) async {
      await tester.pumpWidget(buildList(selected: {'id-notes.pdf'}, onSelectAll: (_) {}));

      final colors = AppTheme.standard(FluentThemeData()).colors;
      expect(_rowFill(tester, 'notes.pdf'), colors.selection);

      final name = tester.widget<Text>(find.text('notes.pdf'));
      expect(name.style?.color, colors.onSelection,
          reason: 'the body colour over an accent fill is dark-on-blue');

      // The size label and the icons travel with it, or half the row stays dark.
      final size = tester.widget<Text>(find.text('2 KB').first);
      expect(size.style?.color, colors.onSelection);
    });

    testWidgets('an unselected row keeps the ordinary text colours', (tester) async {
      await tester.pumpWidget(buildList());

      final colors = AppTheme.standard(FluentThemeData()).colors;
      expect(tester.widget<Text>(find.text('notes.pdf')).style?.color, isNot(colors.onSelection));
    });

    testWidgets('a running operation disables the rows', (tester) async {
      var pressed = false;
      await tester.pumpWidget(buildList(enabled: false, onPressed: (_) => pressed = true));

      await tester.tap(find.text('notes.pdf'));
      await tester.pumpAndSettle();
      expect(pressed, isFalse);
    });
  });

  group('FileManagerDetails', () {
    Widget buildDetails(List<FileManagerEntry> selected, {bool enabled = true}) => wrap(FileManagerDetails(
          selected: selected,
          fileService: fileService,
          onRename: enabled ? () {} : null,
          onMove: enabled ? () {} : null,
          onDelete: enabled ? () {} : null,
        ));

    testWidgets('nothing selected asks for a selection instead of showing empty fields', (tester) async {
      await tester.pumpWidget(buildDetails(const []));

      expect(find.text('Select a file to see its details.'), findsOneWidget);
      expect(find.text('Rename'), findsNothing);
    });

    testWidgets('one file shows its metadata and every action', (tester) async {
      await tester.pumpWidget(buildDetails([FileEntry(file('report.pdf', size: 3 * 1024 * 1024))]));

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('application/pdf'), findsOneWidget);
      expect(find.text('3.0 MB'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('a folder has no size or content type to show', (tester) async {
      await tester.pumpWidget(buildDetails([const FolderEntry('docs/archive')]));

      expect(find.text('archive'), findsOneWidget);
      expect(find.text('Folder'), findsOneWidget);
      expect(find.text('Size'), findsNothing);
    });

    testWidgets('several selected drops rename and totals the sizes', (tester) async {
      await tester.pumpWidget(buildDetails([
        FileEntry(file('a.pdf', size: 1024)),
        FileEntry(file('b.pdf', size: 3072)),
      ]));

      expect(find.text('2 items selected'), findsOneWidget);
      expect(find.text('4 KB'), findsOneWidget);
      expect(find.text('Delete 2 items'), findsOneWidget);
      // Renaming two files at once has no meaning, so the action is not offered.
      expect(find.text('Rename'), findsNothing);
    });

    testWidgets('a running operation disables the actions', (tester) async {
      await tester.pumpWidget(buildDetails([FileEntry(file('a.pdf'))], enabled: false));

      final buttons = tester.widgetList<Button>(find.byType(Button)).toList();
      expect(buttons.every((b) => b.onPressed == null), isTrue);
    });
  });

  group('showNamePromptDialog', () {
    Future<String?> open(WidgetTester tester, {required String initial}) async {
      String? result;
      var opened = false;
      await tester.pumpWidget(FluentApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          if (!opened) {
            opened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              result = await showNamePromptDialog(
                context,
                title: 'New folder',
                initialValue: initial,
                confirmLabel: 'Create',
                validate: folderNameValidator(const ['images']),
              );
            });
          }

          return const ScaffoldPage(content: SizedBox.shrink());
        }),
      ));
      // Not pumpAndSettle: the dialog's background pattern animates forever, so
      // it would never return.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      return result;
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextBox), text);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('opens without reading localizations too early', (tester) async {
      // The regression: resolving the initial validation message in initState is
      // an inherited-widget lookup before dependencies are ready, and asserts.
      await open(tester, initial: '');

      expect(find.text('New folder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an untouched blank field disables OK without scolding', (tester) async {
      await open(tester, initial: '');

      expect(find.text('Enter a name.'), findsNothing);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('an invalid name explains itself once typed', (tester) async {
      await open(tester, initial: '');

      await type(tester, 'a/b');

      expect(find.text("A folder name can't contain a slash."), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('a duplicate is refused against the siblings it was given', (tester) async {
      await open(tester, initial: '');

      await type(tester, 'Images');

      expect(find.text('There is already a folder with that name here.'), findsOneWidget);
    });

    testWidgets('a valid name enables OK', (tester) async {
      await open(tester, initial: '');

      await type(tester, 'holiday');

      expect(find.text('Enter a name.'), findsNothing);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    });
  });
}

/// The fill behind the row that shows [name].
///
/// Found by walking up from the label rather than by index: fluent's own
/// [Checkbox] is built from an [AnimatedContainer] too, so a positional lookup
/// picks one of those about as often as it picks a row.
Color _rowFill(WidgetTester tester, String name) {
  final container = tester.widget<AnimatedContainer>(
    find.ancestor(of: find.text(name), matching: find.byType(AnimatedContainer)),
  );

  return (container.decoration! as ShapeDecoration).color!;
}
