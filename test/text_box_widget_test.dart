import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/color_picker_dialog.dart';
import 'package:h3xboard/views/board_screen/components/widgets/text_box_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Renders [child] the way the board does: localized, and free to take its own
/// size the way a canvas widget does.
Widget _host(Widget child) => FluentApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(child: child),
    );

void main() {
  // Measure against a bundled family. Going through google_fonts here would kick
  // off an async font load that outlives the test and fails it after it passed.
  setUpAll(() => TextBoxWidget.debugFontFamily = 'Roboto');

  group('TextBoxWidget sizing', () {
    // ManipulableBoardWidget lays the child out at naturalSize and then stretches
    // it with BoxFit.fill, so a size that disagrees with what the child wants
    // distorts the glyphs instead of clipping them. These pin the agreement.

    test('empty and whitespace-only text fall back to the placeholder size', () {
      // Guards the toolbar button, which starts from an empty config — a
      // zero-sized default would be invisible and impossible to grab.
      expect(TextBoxWidget.sizeFor(const TextBoxConfig()), TextBoxWidget.placeholderSize);
      expect(TextBoxWidget.sizeFor(const TextBoxConfig(text: '   \n  ')), TextBoxWidget.placeholderSize);
    });

    test('the reported size is the measured text plus the highlight padding', () {
      const config = TextBoxConfig(text: 'Hello');
      final (:textSize, :padding) = TextBoxWidget.measure(config);

      final size = TextBoxWidget.sizeFor(config);

      // RoundedBackgroundText reports only the text box and paints its background
      // outside it, so the padding must be real space in our size or the
      // highlight gets clipped at the edges.
      expect(size.width, textSize.width + padding.horizontal);
      expect(size.height, textSize.height + padding.vertical);
      expect(padding.horizontal, greaterThan(0));
      expect(padding.vertical, greaterThan(0));
    });

    test('text wraps at contentWidth instead of growing without bound', () {
      const short = TextBoxConfig(text: 'Hi');
      final long = TextBoxConfig(text: List.filled(80, 'word').join(' '));

      final longSize = TextBoxWidget.sizeFor(long);
      final (:textSize, :padding) = TextBoxWidget.measure(long);

      expect(textSize.width, lessThanOrEqualTo(TextBoxWidget.contentWidth));
      expect(longSize.width, lessThanOrEqualTo(TextBoxWidget.contentWidth + padding.horizontal));
      expect(longSize.height, greaterThan(TextBoxWidget.sizeFor(short).height));
    });

    test('a larger font size yields a larger box', () {
      final small = TextBoxWidget.sizeFor(const TextBoxConfig(text: 'Hello', fontSize: 32));
      final large = TextBoxWidget.sizeFor(const TextBoxConfig(text: 'Hello', fontSize: 128));

      expect(large.height, greaterThan(small.height));
    });
  });

  group('TextBoxWidget editor', () {
    // Opens the editor the way the board does — from a widget's own context —
    // and hands back the config it commits, or null when nothing was committed.
    Future<TextBoxConfig? Function()> openEditor(
      WidgetTester tester, {
      TextBoxConfig config = const TextBoxConfig(text: 'Hello'),
    }) async {
      TextBoxConfig? saved;
      await tester.pumpWidget(_host(
        Builder(
          builder: (context) => Button(
            onPressed: () => showTextBoxEditor(context, config, (updated) => saved = updated as TextBoxConfig),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () => saved;
    }

    testWidgets('it edits the label itself, not a text box in a card', (tester) async {
      await openEditor(tester);

      // The preview *is* the label widget, with an input layer over it that
      // contributes only the caret — so it cannot drift from the board.
      expect(find.byType(TextBoxWidget), findsOneWidget);
      expect(tester.widget<TextBoxWidget>(find.byType(TextBoxWidget)).config.text, 'Hello');
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'Hello');
    });

    testWidgets('dismissing the scrim keeps what was typed', (tester) async {
      final saved = await openEditor(tester);

      await tester.enterText(find.byType(EditableText), 'Hello there');
      await tester.pump();
      // The label renders the typed text, not the field: they share one config.
      expect(tester.widget<TextBoxWidget>(find.byType(TextBoxWidget)).config.text, 'Hello there');
      // Anywhere outside the editor is the scrim.
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(saved()?.text, 'Hello there');
    });

    testWidgets('Escape drops the edit', (tester) async {
      final saved = await openEditor(tester);

      await tester.enterText(find.byType(EditableText), 'Hello there');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(TextBoxWidget), findsNothing);
      expect(saved(), isNull);
    });

    testWidgets('the style bar restyles the preview and is committed with it', (tester) async {
      final saved = await openEditor(tester);

      await tester.tap(find.widgetWithIcon(ToggleButton, LucideIcons.alignCenter));
      await tester.pumpAndSettle();

      expect(tester.widget<TextBoxWidget>(find.byType(TextBoxWidget)).config.textAlign, TextAlign.center);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(saved()?.textAlign, TextAlign.center);
    });

    testWidgets('the colour buttons open the picker', (tester) async {
      await openEditor(tester);

      await tester.tap(find.widgetWithIcon(Button, LucideIcons.type));
      // Fixed pumps rather than pumpAndSettle: the picker rides in on a dialog
      // whose background pattern animates forever, so nothing ever settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ColorPickerDialog), findsOneWidget);
    });
  });
}
