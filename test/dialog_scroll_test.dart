import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/theme/theme.dart';
import 'package:h3xboard/views/board_screen/components/widgets/todo_list_widget.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:h3xboard/views/components/dialogs/dialog_scroll_area.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:h3xboard/views/components/dialogs/widget_gallery_dialog.dart';

/// Hosts a dialog the way `showAppDialog` does, minus the route: under the app
/// theme, localized, and at whatever surface size the test set.
///
/// [viewInsetsBottom] stands in for the on-screen keyboard, which is the whole
/// reason these dialogs run out of room.
Widget _host(
  Widget dialog, {
  double viewInsetsBottom = 0,
  EdgeInsets padding = EdgeInsets.zero,
}) =>
    FluentApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: padding,
            viewInsets: EdgeInsets.only(bottom: viewInsetsBottom),
          ),
          child: dialog,
        ),
      ),
    );

/// Opens [dialog] through `showAppDialog`, so the route's own insets are part of
/// what gets measured.
Widget _route(Widget dialog, {required EdgeInsets padding}) => FluentApp(
      theme: buildAppTheme(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: padding),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Button(
          onPressed: () => showAppDialog<void>(context: context, builder: (_) => dialog),
          child: const Text('open'),
        ),
      ),
    );

/// The shape of the to-do list's Edit items dialog: a title field above an
/// eight-line item field that keeps growing as the user types.
Widget _todoStyleContent() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const ContinuousTextBox(placeholder: 'Title'),
        const SizedBox(height: 12),
        ContinuousTextBox(
          controller: TextEditingController(text: List.generate(12, (i) => 'Task $i').join('\n')),
          maxLines: null,
          minLines: 8,
          placeholder: 'One per line',
        ),
      ],
    );

ThemableContentDialog _dialog({
  required Widget content,
  bool scrollableContent = true,
}) =>
    ThemableContentDialog(
      title: const Text('Edit'),
      constraints: const BoxConstraints(maxWidth: 520),
      // The pattern animates forever, so pumpAndSettle would never return.
      showBackgroundPattern: false,
      scrollableContent: scrollableContent,
      content: content,
      actions: [
        Button(onPressed: () {}, child: const Text('Cancel')),
        FilledButton(onPressed: () {}, child: const Text('Save')),
      ],
    );

/// The scrollable belonging to the dialog body, ignoring the ones text fields
/// carry around inside themselves.
Finder _bodyScrollable() => find.descendant(
      of: find.byType(DialogScrollArea),
      matching: find.byType(Scrollable),
    );

/// How tall the dialog card stands, measured title-top to actions-bottom.
///
/// Deliberately not `getSize(find.byType(ThemableContentDialog))`: the dialog's
/// root is the full-screen inset wrapper, so that measures the viewport and
/// quietly passes whatever the card does.
double _cardExtent(WidgetTester tester) =>
    tester.getRect(find.text('Save')).bottom - tester.getRect(find.text('Edit')).top;

void main() {
  group('ThemableContentDialog scrolling', () {

    testWidgets('content that outgrows the dialog scrolls instead of overflowing', (tester) async {
      // The bug this exists for: on a phone with the keyboard up, the to-do
      // list's Edit items dialog overran its box and clipped behind the actions
      // bar, with a RenderFlex overflow in the console.
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(_dialog(content: _todoStyleContent()), viewInsetsBottom: 336));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final position = tester.state<ScrollableState>(_bodyScrollable().first).position;
      expect(position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('the actions bar stays on screen while the body scrolls', (tester) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(_dialog(content: _todoStyleContent()), viewInsetsBottom: 336));
      await tester.pumpAndSettle();

      // Save is what makes the dialog worth opening; clipping it was the part of
      // the overflow that actually cost the user their edit.
      final save = tester.getRect(find.text('Save'));
      expect(save.bottom, lessThanOrEqualTo(780 - 336));
    });

    testWidgets('content that already fits keeps the height it had', (tester) async {
      // Wrapping every dialog by default is only safe because the scroll view
      // sizes to its child: a two-line confirmation must not grow to fill — and
      // must not pick up the tail gap either, which is spent on the same extent
      // and so would read as dead space rather than a scroll affordance.
      const content = Text('Are you sure?');

      await tester.pumpWidget(_host(_dialog(content: content, scrollableContent: false)));
      await tester.pumpAndSettle();
      final unwrapped = _cardExtent(tester);

      await tester.pumpWidget(_host(_dialog(content: content)));
      await tester.pumpAndSettle();

      expect(_cardExtent(tester), moreOrLessEquals(unwrapped));
      expect(tester.state<ScrollableState>(_bodyScrollable().first).position.maxScrollExtent, 0);
    });

    testWidgets('content that scrolls gets a gap at each end', (tester) async {
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(_dialog(content: _todoStyleContent()), viewInsetsBottom: 336));
      await tester.pumpAndSettle();

      final area = tester.getRect(find.byType(DialogScrollArea));
      // At rest the first row sits a hair below the top edge...
      expect(
        tester.getRect(find.byType(ContinuousTextBox).first).top - area.top,
        moreOrLessEquals(kScrollStartPadding),
      );

      // ...and scrolled all the way down, the last row comes to rest short of
      // the bottom edge rather than flush against it.
      final position = tester.state<ScrollableState>(_bodyScrollable().first).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();

      expect(
        area.bottom - tester.getRect(find.byType(ContinuousTextBox).last).bottom,
        moreOrLessEquals(kScrollEndPadding),
      );
    });

    testWidgets('the clip keeps the vertical bounds and relaxes the sideways ones', (tester) async {
      // A viewport clips to its own box the moment it has something to scroll.
      // Vertically that is wanted — it stops rows painting over the title and
      // the actions bar. Sideways it only ever shaved the left and right border
      // off every field, because a ContinuousRectangleBorder strokes half its
      // width outside the path it draws.
      await tester.pumpWidget(_host(_dialog(content: _todoStyleContent())));
      await tester.pumpAndSettle();

      final clipper = tester
          .widgetList<ClipRect>(find.descendant(
            of: find.byType(DialogScrollArea),
            matching: find.byType(ClipRect),
          ))
          .map((clip) => clip.clipper)
          .whereType<RelaxedHorizontalClipper>()
          .single;

      expect(
        clipper.getClip(const Size(200, 100)),
        const Rect.fromLTRB(-kDialogScrollBleed, 0, 200 + kDialogScrollBleed, 100),
      );
    });

    testWidgets('relaxing the clip leaves the layout untouched', (tester) async {
      // The whole reason it is a clip rather than borrowed padding: it buys the
      // border its room without any caller giving anything up, so wrapping
      // content changes nothing about where that content sits.
      //
      // The Column is not decoration: handed a bare TextBox, fluent expands it
      // to whatever loose height the content slot offers, and every real dialog
      // wraps its content in a min-sized Column for exactly that reason.
      const content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ContinuousTextBox(placeholder: 'Title')],
      );

      await tester.pumpWidget(_host(_dialog(content: content, scrollableContent: false)));
      await tester.pumpAndSettle();
      final unwrappedField = tester.getRect(find.byType(ContinuousTextBox));
      final unwrappedTitle = tester.getRect(find.text('Edit'));

      await tester.pumpWidget(_host(_dialog(content: content)));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byType(ContinuousTextBox)), unwrappedField);
      expect(tester.getRect(find.text('Edit')), unwrappedTitle);
    });

    testWidgets('scrollableContent: false leaves the content unwrapped', (tester) async {
      await tester.pumpWidget(_host(_dialog(content: const Text('hi'), scrollableContent: false)));
      await tester.pumpAndSettle();

      expect(find.byType(DialogScrollArea), findsNothing);
    });

    testWidgets('the safe area and the minimum gap merge instead of stacking', (tester) async {
      // The reported symptom: a notched phone spent its inset twice — fluent's
      // dialog route wrapped every dialog in a SafeArea (~59px) and the app's
      // own helper added 24px underneath it, leaving 83px of dead space above
      // the card while the keyboard ate the bottom. The gap is now max(), not
      // sum(), and `showAppDialog` owns the only SafeArea in the chain.
      const statusBar = 59.0;
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_route(
        _dialog(content: const Text('Are you sure?')),
        padding: const EdgeInsets.only(top: statusBar),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Asserted by inspection rather than geometry: the entrance transition
      // deliberately settles a hair under 1.0 scale, which shifts every painted
      // rect in the dialog.
      final inset = tester.widget<AnimatedPadding>(find.descendant(
        of: find.byType(ThemableContentDialog),
        matching: find.byType(AnimatedPadding),
      ));
      expect(inset.padding, const EdgeInsets.only(left: 24, top: statusBar, right: 24, bottom: 24));

      // And the route contributes no second inset of its own.
      expect(
        find.ancestor(of: find.byType(ThemableContentDialog), matching: find.byType(SafeArea)),
        findsNothing,
      );
    });

    testWidgets('the to-do list Edit items dialog scrolls with the keyboard up', (tester) async {
      // Drives the real descriptor rather than a stand-in: the shell tests above
      // all passed while this dialog — the one the scroll area was written for —
      // shipped with scrollableContent: false, so nothing covered the call site.
      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(FluentApp(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(viewInsets: const EdgeInsets.only(bottom: 336)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Button(
            onPressed: TodoListWidgetDescriptor.instance.editAction(
              context,
              TodoListConfig(items: List.generate(12, (i) => TodoItem(text: 'Task $i'))),
              (_) {},
            ),
            child: const Text('edit'),
          ),
        ),
      ));

      await tester.tap(find.text('edit'));
      // Fixed pumps rather than pumpAndSettle: this dialog keeps its animated
      // pattern, which never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(DialogScrollArea), findsOneWidget);
      expect(tester.state<ScrollableState>(_bodyScrollable().first).position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('the widget gallery opts out and still builds', (tester) async {
      // Its samples scroll themselves under a top-level Flexible, which asserts
      // if it is handed the unbounded height a scroll view gives its child.
      await tester.pumpWidget(_host(const WidgetGalleryDialog()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(DialogScrollArea), findsNothing);
    });

  });
}
