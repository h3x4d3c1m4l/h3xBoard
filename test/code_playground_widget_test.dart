import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/programming_language.dart';
import 'package:h3xboard/services/python/python_runtime.dart';
import 'package:h3xboard/views/board_screen/components/board_mirror_scope.dart';
import 'package:h3xboard/views/board_screen/components/canvas_text_editing_scope.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_style.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/components/editor_pane.dart';

/// Releases focus so the editor stops blinking its caret.
///
/// The editor blinks its caret on a repeating timer while focused, and the test
/// binding fails a test that ends with a timer still pending. Dropping focus
/// stops it, which is what leaving the widget would do anyway.
Future<void> dropFocus(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// Hosts [child] the way the board does — localized, at exactly the size the
/// descriptor promised.
Widget _host(Widget child) => FluentApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: FluentThemeData(accentColor: const Color(0xFF00FF80).toAccentColor()),
      home: Center(child: child),
    );

/// Stands in for the interpreter, so the run path is testable off the web.
class _FakeRuntime implements PythonRuntime {

  final PythonResult result;
  final Duration delay;
  String? lastCode;
  String? lastStdin;

  _FakeRuntime(this.result, {this.delay = Duration.zero});

  @override
  bool get isSupported => true;

  @override
  Future<void> ready() async {}

  @override
  Future<PythonResult> run(String code, {String stdin = ''}) async {
    lastCode = code;
    lastStdin = stdin;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}

}

void main() {
  // google_fonts in a widget test starts an async load that outlives the test.
  setUpAll(() => CodePlaygroundStyle.debugFontFamily = 'Roboto');

  const descriptor = CodePlaygroundWidgetDescriptor.instance;

  Future<void> pump(WidgetTester tester, CodePlaygroundConfig config) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      SizedBox.fromSize(
        size: descriptor.naturalSize(config),
        child: CodePlaygroundWidget(config: config, onChanged: (_) {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('naturalSize agrees with what the widget lays out', () {
    // ManipulableBoardWidget reads naturalSize *before* layout and stretches the
    // child to it with BoxFit.fill, so a disagreement smears the glyphs rather
    // than clipping. An overflow throws in tests, which is the tripwire.
    testWidgets('for an empty program, a long one, and lots of output', (tester) async {
      final configs = [
        const CodePlaygroundConfig(),
        const CodePlaygroundConfig(code: ''),
        // A program far longer than the editor: it must scroll, not resize.
        CodePlaygroundConfig(code: List.filled(200, 'print("line")').join('\n')),
        // Likewise a wall of output.
        CodePlaygroundConfig(
          stdout: List.filled(400, 'output line').join('\n'),
          exitCode: 0,
          outputTruncated: true,
        ),
        const CodePlaygroundConfig(
          stderr: 'Traceback (most recent call last):\n  File "/main.py", line 1\nZeroDivisionError',
          exitCode: 1,
        ),
        const CodePlaygroundConfig(stdinText: 'Sander\n41\n'),
      ];

      for (final config in configs) {
        await pump(tester, config);
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflows the ${descriptor.naturalSize(config)} it reported',
        );
      }
    });

    test('the size never depends on the content', () {
      // Anything else would mean the widget resizes as someone types.
      final long = 'x' * 5000;
      final sizes = {
        descriptor.naturalSize(const CodePlaygroundConfig()),
        descriptor.naturalSize(CodePlaygroundConfig(code: long)),
        descriptor.naturalSize(CodePlaygroundConfig(stdout: long)),
      };
      expect(sizes, hasLength(1));
    });
  });

  group('the toolbar', () {
    testWidgets('names the language and its version', (tester) async {
      await pump(tester, const CodePlaygroundConfig());
      expect(find.text('Python 3.14.7'), findsOneWidget);
      expect(ProgrammingLanguage.python.label, 'Python $kPythonVersion');
    });

    testWidgets('says so where running is not available yet', (tester) async {
      // Tests run on the VM, where the conditional import resolves to the stub —
      // the same path iOS and Android take until the Rust runtime lands.
      expect(createPythonRuntime().isSupported, isFalse);

      await pump(tester, const CodePlaygroundConfig());
      expect(find.textContaining('only available on the web app'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });
  });

  group('the output panel', () {
    testWidgets('tells "never run" apart from "printed nothing"', (tester) async {
      await pump(tester, const CodePlaygroundConfig());
      expect(find.textContaining('Press Run'), findsOneWidget);

      // exitCode set but no output: it ran and printed nothing.
      await pump(tester, const CodePlaygroundConfig(exitCode: 0, durationMs: 12));
      expect(find.textContaining('Press Run'), findsNothing);
      expect(find.textContaining('finished in 12 ms'), findsOneWidget);
    });

    testWidgets('marks a failed run', (tester) async {
      await pump(tester, const CodePlaygroundConfig(stderr: 'ZeroDivisionError', exitCode: 1));
      expect(find.textContaining('stopped with an error'), findsOneWidget);
    });

    testWidgets('flags truncated output rather than silently dropping it', (tester) async {
      await pump(tester, const CodePlaygroundConfig(
        stdout: 'lots',
        exitCode: 0,
        outputTruncated: true,
      ));
      expect(find.textContaining('cut short'), findsOneWidget);
    });
  });

  group('registration', () {
    test('is in the catalog and resolves through the registry', () {
      expect(widgetRegistry[CodePlaygroundConfig], CodePlaygroundWidgetDescriptor.instance);
      expect(descriptorFor(const CodePlaygroundConfig()), isA<CodePlaygroundWidgetDescriptor>());
      expect(descriptor.showInCatalog, isTrue);
    });

    testWidgets('the catalog thumbnail renders with a no-op callback', (tester) async {
      // widget_catalog_dialog and read_only_board both build exactly this.
      tester.view.physicalSize = const Size(2400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final config = descriptor.defaultConfig;
      await tester.pumpWidget(_host(
        SizedBox.fromSize(
          size: descriptor.naturalSize(config),
          child: descriptor.buildWidget(config, (_) {}),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byType(CodePlaygroundWidget), findsOneWidget);
    });
  });

  group('running a program', () {
    testWidgets('output lands in the config, and the editor keeps the keyboard', (tester) async {
      tester.view.physicalSize = const Size(2400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var config = const CodePlaygroundConfig(code: 'print("hi")');
      final runtime = _FakeRuntime(const PythonResult(
        stdout: 'hi\n',
        stderr: '',
        duration: Duration(milliseconds: 87),
      ));

      await tester.pumpWidget(_host(
        StatefulBuilder(
          builder: (context, setState) => SizedBox.fromSize(
            size: descriptor.naturalSize(config),
            child: CodePlaygroundWidget(
              config: config,
              debugRuntime: runtime,
              onChanged: (updated) => setState(() => config = updated),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(runtime.lastCode, 'print("hi")');
      expect(config.stdout, 'hi\n');
      expect(config.exitCode, 0);
      expect(config.durationMs, 87);
      expect(find.textContaining('finished in 87 ms'), findsOneWidget);

      await dropFocus(tester);
    });

    testWidgets('Run and Stop are one button, so the focus node survives', (tester) async {
      // Swapping widget types here remounts the subtree and disposes the
      // button's focus node mid-run, which left focus nowhere and made the
      // editor silently ignore every keystroke after a run.
      tester.view.physicalSize = const Size(2400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final runtime = _FakeRuntime(
        const PythonResult(stdout: 'done\n', stderr: ''),
        delay: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(_host(
        SizedBox.fromSize(
          size: descriptor.naturalSize(const CodePlaygroundConfig()),
          child: CodePlaygroundWidget(
            config: const CodePlaygroundConfig(),
            debugRuntime: runtime,
            onChanged: (_) {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Run'), findsOneWidget);

      await tester.tap(find.text('Run'));
      await tester.pump();

      // Mid-run: same button, different label — not a second widget type.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Run'), findsOneWidget);

      await dropFocus(tester);
    });
  });

  group('keeping the keyboard attached', () {
    testWidgets('the board can see that the editor is being typed into', (tester) async {
      // board.dart claims keys — L arms the laser, Backspace deletes the widget
      // being arranged — unless it can tell the user is typing. It decides that
      // by walking up from whatever holds focus, looking for an EditableText or
      // a CanvasTextEditingScope. re_editor is neither a text field nor an
      // EditableText — it drives the platform input itself — so without the
      // marker that walk comes up empty and the board swallows every keystroke
      // while the pane still shows a caret and allows selection.
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(_host(
        SizedBox(
          width: 500,
          height: 260,
          child: EditorPane(text: 'print(1)', focusNode: node, onChanged: (_, _) {}),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue, reason: 'precondition: the editor holds focus');

      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull, reason: 'something must hold focus for the board to inspect');
      expect(
        focused!.findAncestorWidgetOfExactType<CanvasTextEditingScope>(),
        isNotNull,
        reason: 'the board would otherwise treat typing as board shortcuts',
      );

      await dropFocus(tester);
    });
  });

  group('on a mirror', () {
    /// Builds the widget the way [ReadOnlyBoard] does — inside the scope, with a
    /// callback that discards what it is handed.
    Future<void> pumpMirrored(WidgetTester tester, CodePlaygroundConfig config) async {
      tester.view.physicalSize = const Size(2400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        BoardMirrorScope(
          child: SizedBox.fromSize(
            size: descriptor.naturalSize(config),
            child: CodePlaygroundWidget(config: config, onChanged: (_) {}),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('nothing can be typed into and nothing can be run', (tester) async {
      // Both panes accepted typing here before, and then snapped back the moment
      // the presenter's next update arrived; Run executed the program on the
      // wrong machine entirely.
      await pumpMirrored(tester, const CodePlaygroundConfig(code: 'print(1)'));

      final panes = tester.widgetList<EditorPane>(find.byType(EditorPane));
      expect(panes, hasLength(2), reason: 'the program and the input');
      expect(panes.every((pane) => pane.readOnly), isTrue);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('the "run it in the web app" note is not shown', (tester) async {
      // True of the mirror too, but useless advice to someone watching a
      // projector — and the disabled button already says as much.
      await pumpMirrored(tester, const CodePlaygroundConfig());
      expect(find.textContaining('only available on the web app'), findsNothing);
    });

    testWidgets('the presenter\'s caret is carried across', (tester) async {
      await pumpMirrored(tester, const CodePlaygroundConfig(
        code: 'a = 1\nb = 2\n',
        caretLine: 1,
        caretColumn: 3,
      ));

      final code = tester.widget<EditorPane>(find.byType(EditorPane).first);
      expect(code.mirroredCaret, (line: 1, column: 3));

      // Null while the presenter is elsewhere, so the mirror shows no caret
      // rather than one left behind on a line they have moved off.
      await pumpMirrored(tester, const CodePlaygroundConfig(code: 'a = 1\n'));
      expect(tester.widget<EditorPane>(find.byType(EditorPane).first).mirroredCaret, isNull);
    });

    testWidgets('the board being edited is not a mirror', (tester) async {
      // The editor deliberately installs no scope, so this holds by omission —
      // and would break silently if anything ever wrapped the whole app in one.
      await pump(tester, const CodePlaygroundConfig());
      expect(tester.widget<EditorPane>(find.byType(EditorPane).first).readOnly, isFalse);
    });
  });

  group('the caret sent to a mirror', () {
    testWidgets('follows the caret, and clears when the pane loses focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final reported = <CodeCaret?>[];

      await tester.pumpWidget(_host(
        SizedBox(
          width: 500,
          height: 260,
          child: EditorPane(
            text: 'a = 1\nb = 2\n',
            focusNode: node,
            onChanged: (_, caret) => reported.add(caret),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      // Focus can arrive without the selection moving — Tab, or the playground
      // handing the caret back after a run — and re_editor reports nothing for
      // that, so the focus listener is the only thing that can.
      node.requestFocus();
      await tester.pump();
      expect(reported.last, isNotNull, reason: 'focus alone must report a caret');

      node.unfocus();
      await tester.pump();
      expect(reported.last, isNull, reason: 'a mirror must stop drawing a stale caret');

      await dropFocus(tester);
    });

    testWidgets('is not echoed back by a pane that is showing one', (tester) async {
      // Applying the mirrored caret moves the pane's own selection, which fires
      // re_editor's onChanged — so without the guard a mirror would report the
      // presenter's caret straight back at them.
      var reports = 0;

      await tester.pumpWidget(_host(
        SizedBox(
          width: 500,
          height: 260,
          child: EditorPane(
            text: 'a = 1\n',
            readOnly: true,
            mirroredCaret: (line: 0, column: 2),
            onChanged: (_, _) => reports++,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(reports, 0);
    });
  });

  group('folding the panes into one config', () {
    /// Drives a pane's callback the way re_editor does, without needing a real
    /// keystroke to reach the platform text input.
    Future<List<CodePlaygroundConfig>> report(
      WidgetTester tester,
      CodePlaygroundConfig config,
      void Function(EditorPane code) act,
    ) async {
      tester.view.physicalSize = const Size(2400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final published = <CodePlaygroundConfig>[];
      await tester.pumpWidget(_host(
        SizedBox.fromSize(
          size: descriptor.naturalSize(config),
          child: CodePlaygroundWidget(
            config: config,
            onChanged: published.add,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      act(tester.widget<EditorPane>(find.byType(EditorPane).first));
      await tester.pump();
      await dropFocus(tester);
      return published;
    }

    testWidgets('an edit and a caret arrive as a single change', (tester) async {
      // They used to be two callbacks, and each copied from the config as it was
      // before *either* — so the caret update quietly put the old code back and
      // typing did nothing.
      final published = await report(
        tester,
        const CodePlaygroundConfig(code: 'a = 1'),
        (code) => code.onChanged('a = 12', (line: 0, column: 6)),
      );

      expect(published, hasLength(1));
      expect(published.single.code, 'a = 12');
      expect(published.single.caretLine, 0);
      expect(published.single.caretColumn, 6);
    });

    testWidgets('a report that changes nothing is not published', (tester) async {
      // The panes report on every notification, most of which move nothing. An
      // identical config is not a runtime-only change, so it would be filed as a
      // board edit and take an undo slot.
      final published = await report(
        tester,
        const CodePlaygroundConfig(code: 'a = 1'),
        (code) => code.onChanged('a = 1', null),
      );
      expect(published, isEmpty);
    });
  });

  group('the block caret drawn into a mirrored line', () {
    const caretStyle = TextStyle(backgroundColor: Color(0xFF00FF80), color: Color(0xFF0B111C));
    const fallback = TextStyle(color: Color(0xFFFFFFFF));

    /// The visible text, so a transformation that drops or duplicates code fails
    /// loudly rather than just looking odd.
    String flatten(TextSpan span) {
      final buffer = StringBuffer(span.text ?? '');
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan) buffer.write(flatten(child));
      }
      return buffer.toString();
    }

    /// Every leaf run with text, in reading order.
    List<TextSpan> runsOf(TextSpan span) => [
          if (span.text != null) span,
          for (final child in span.children ?? const <InlineSpan>[])
            if (child is TextSpan) ...runsOf(child),
        ];

    /// The one run carrying the caret's background.
    TextSpan? caretRun(TextSpan span) {
      if (span.style?.backgroundColor == caretStyle.backgroundColor && span.text != null) return span;
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan) {
          final found = caretRun(child);
          if (found != null) return found;
        }
      }
      return null;
    }

    TextSpan withCaret(TextSpan span, int column) =>
        spanWithBlockCaret(span, column: column, fallbackStyle: fallback, caretStyle: caretStyle);

    // What re_editor's highlighter hands over: one span per coloured token.
    TextSpan highlighted() => const TextSpan(children: [
          TextSpan(text: 'print', style: TextStyle(color: Color(0xFF61AFEF))),
          TextSpan(text: '('),
          TextSpan(text: '"hi"', style: TextStyle(color: Color(0xFF98C379))),
          TextSpan(text: ')'),
        ]);

    test('inverts exactly one character and leaves the line intact', () {
      for (var column = 0; column < 'print("hi")'.length; column++) {
        final result = withCaret(highlighted(), column);
        expect(flatten(result), 'print("hi")', reason: 'at column $column');
        expect(caretRun(result)?.text, 'print("hi")'[column], reason: 'at column $column');
      }
    });

    test('inverts only the caret character, not the token around it', () {
      // Splitting a token to invert one letter must not flatten the colour of
      // the letters either side of it.
      final result = withCaret(highlighted(), 1);
      expect(caretRun(result)?.style?.color, caretStyle.color, reason: 'the caret gets its own ink');

      const tokenColor = Color(0xFF61AFEF);
      final rest = runsOf(result).where((run) => run.text != 'r' && 'print'.contains(run.text!));
      expect(rest, isNotEmpty);
      expect(rest.every((run) => run.style?.color == tokenColor), isTrue,
          reason: 'the rest of `print` stays keyword-coloured');
    });

    test('stands a space in past the end of a line, and on an empty one', () {
      final atEnd = withCaret(highlighted(), 'print("hi")'.length);
      expect(flatten(atEnd), 'print("hi") ');
      expect(caretRun(atEnd)?.text, ' ');

      final empty = withCaret(const TextSpan(text: ''), 0);
      expect(caretRun(empty)?.text, ' ');
    });

    test('gives up rather than dropping anything it cannot flatten', () {
      // A non-TextSpan child cannot survive flattening, and losing code off a
      // mirrored line is far worse than losing the caret.
      const span = TextSpan(children: [
        TextSpan(text: 'ab'),
        WidgetSpan(child: SizedBox.shrink()),
      ]);
      expect(identical(withCaret(span, 0), span), isTrue);
    });
  });

  group('board integration', () {
    test('every change is runtime-only, so typing never consumes undo', () {
      const before = CodePlaygroundConfig();
      for (final after in <CodePlaygroundConfig>[
        CodePlaygroundConfig(code: 'print(1)'),
        CodePlaygroundConfig(stdinText: 'x'),
        CodePlaygroundConfig(stdout: 'hello', exitCode: 0),
        CodePlaygroundConfig(caretLine: 3, caretColumn: 7),
      ]) {
        expect(isWidgetRuntimeOnlyChange(before, after), isTrue, reason: after.toString());
      }
    });

    test('code, output and the caret round-trip through JSON, so they mirror', () {
      const config = CodePlaygroundConfig(
        code: 'print("hi")',
        stdinText: 'a\nb',
        stdout: 'hi\n',
        exitCode: 0,
        durationMs: 42,
        caretLine: 1,
        caretColumn: 4,
      );
      expect(BoardWidgetConfig.fromJson(config.toJson()), config);
    });
  });
}
