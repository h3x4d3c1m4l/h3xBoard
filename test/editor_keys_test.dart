import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_style.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/components/editor_pane.dart';

/// Keys that must move the caret rather than the focus.
///
/// re_editor installs its keyboard shortcuts on desktop only — on Android and
/// iOS it wraps itself in a bare `Focus` that handles Backspace and Enter and
/// nothing else, assuming a soft keyboard with no arrows and no Tab. With a
/// hardware keyboard those keys fall through to Flutter's defaults, which read
/// an arrow as `DirectionalFocusIntent` and Tab as `NextFocusIntent`: pressing
/// Down in a program moves focus out of the editor.
///
/// These tests run on the VM, where `defaultTargetPlatform` reports Android —
/// which is precisely the branch that has the problem, so this reproduces the
/// device behaviour rather than the desktop one.
Widget _host(Widget child) => FluentApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: FluentThemeData(accentColor: const Color(0xFF00FF80).toAccentColor()),
      home: child,
    );

/// Releases focus so the caret stops blinking; the binding fails a test that
/// ends with a timer still pending.
Future<void> dropFocus(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => CodePlaygroundStyle.debugFontFamily = 'Roboto');

  /// Two panes, so "focus went somewhere else" is observable rather than
  /// inferred.
  testWidgets('arrows and Tab stay in the editor instead of traversing', (tester) async {
    final code = FocusNode(debugLabel: 'code');
    final other = FocusNode(debugLabel: 'other');
    addTearDown(code.dispose);
    addTearDown(other.dispose);

    var text = 'one\ntwo\nthree\n';
    await tester.pumpWidget(_host(Column(
      children: [
        SizedBox(
          width: 500,
          height: 200,
          child: EditorPane(
            text: text,
            focusNode: code,
            showLineNumbers: true,
            onChanged: (updated, _) => text = updated,
          ),
        ),
        SizedBox(
          width: 500,
          height: 200,
          child: EditorPane(text: 'other', focusNode: other, onChanged: (_, _) {}),
        ),
      ],
    )));
    await tester.pump(const Duration(milliseconds: 300));

    code.requestFocus();
    await tester.pump();
    expect(code.hasFocus, isTrue, reason: 'precondition: the editor holds focus');

    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.tab,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(code.hasFocus, isTrue, reason: '$key moved focus out of the editor');
      expect(other.hasFocus, isFalse, reason: '$key traversed to the next pane');
    }

    await dropFocus(tester);
  });

  testWidgets('Tab indents the program rather than doing nothing', (tester) async {
    final code = FocusNode(debugLabel: 'code');
    addTearDown(code.dispose);

    var text = 'one\n';
    await tester.pumpWidget(_host(SizedBox(
      width: 500,
      height: 200,
      child: EditorPane(
        text: text,
        focusNode: code,
        showLineNumbers: true,
        onChanged: (updated, _) => text = updated,
      ),
    )));
    await tester.pump(const Duration(milliseconds: 300));

    code.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(text, isNot('one\n'), reason: 'Tab must put indentation in, not just be swallowed');

    await dropFocus(tester);
  });

  testWidgets('a read-only pane swallows Tab rather than traversing', (tester) async {
    // A mirror has nowhere sensible to send focus either, and letting Tab
    // through is the bug this all exists to fix.
    final code = FocusNode(debugLabel: 'code');
    final other = FocusNode(debugLabel: 'other');
    addTearDown(code.dispose);
    addTearDown(other.dispose);

    await tester.pumpWidget(_host(Column(
      children: [
        SizedBox(
          width: 500,
          height: 200,
          child: EditorPane(text: 'one\n', focusNode: code, readOnly: true, onChanged: (_, _) {}),
        ),
        SizedBox(
          width: 500,
          height: 200,
          child: EditorPane(text: 'other', focusNode: other, onChanged: (_, _) {}),
        ),
      ],
    )));
    await tester.pump(const Duration(milliseconds: 300));

    code.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(other.hasFocus, isFalse);

    await dropFocus(tester);
  });
}
