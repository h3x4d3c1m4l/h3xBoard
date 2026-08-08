import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/board_screen/components/canvas_text_editing_scope.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_metrics.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_style.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/python.dart';

/// A text pane backed by `re_editor` — used for both the program and the input,
/// so there is one editing mechanism to reason about.
///
/// Two editors were tried and rejected first. `code_forge_web` attaches its
/// platform text input once, inside a focus-change listener, and never checks
/// again — so when the browser tore the hidden input element out of the DOM
/// (reliably after a paste) the pane kept its caret, kept selecting, and
/// silently swallowed every key with no way back. re_editor reattaches whenever
/// focus or the editable state changes, which is exactly the property that was
/// missing. `flutter_code_editor` was tried in between: its `CodeField` is a
/// Material `TextField`, so it wants a `Material` ancestor in a fluent_ui app,
/// its `wrap` parameter is declared but never read, and its autocomplete popup
/// is an `OverlayEntry` placed at global coordinates — which the board's
/// `FittedBox` scale puts somewhere else entirely.

/// A caret as a place in the text: which line, and how many characters into it.
///
/// Line and column rather than a flat offset because that is the shape re_editor
/// works in, so neither side has to walk the text to convert.
typedef CodeCaret = ({int line, int column});

class EditorPane extends StatefulWidget {

  final String text;

  /// False for plain text — the input pane wants no keywords coloured.
  final bool highlightPython;

  /// Line numbers down the side. Wanted for a program, noise beside two lines of
  /// input.
  final bool showLineNumbers;

  final double fontSize;
  final bool readOnly;

  /// Reports the text *and* the caret together, whenever either moves.
  ///
  /// One callback rather than two on purpose: a caller folds both into a single
  /// config, and two calls in the same tick would each `copyWith` from the
  /// config as it was *before* either — so whichever landed second would quietly
  /// undo the first.
  ///
  /// The caret is null while the pane does not have focus, which is what tells a
  /// mirror to stop drawing a caret the presenter has moved away from instead of
  /// leaving a stale one behind.
  final void Function(String text, CodeCaret? caret) onChanged;

  /// Where someone else's caret is, for a pane showing a presenter's editing
  /// rather than doing its own. null — the normal case — means this pane owns
  /// its caret and re_editor blinks it in the usual way.
  ///
  /// Only meaningful together with [readOnly]; see [spanWithBlockCaret] for why
  /// a mirrored caret has to be drawn into the text rather than blinked. Such a
  /// pane reports nothing through [onChanged] — it has nothing of its own to
  /// say, and echoing the caret back would fight the presenter for it.
  final CodeCaret? mirroredCaret;

  /// Supplied when the caller needs to put focus back after taking it — the
  /// playground returns the caret to the code pane once a run finishes.
  final FocusNode? focusNode;

  const EditorPane({
    super.key,
    required this.text,
    required this.onChanged,
    this.highlightPython = false,
    this.showLineNumbers = false,
    this.fontSize = kCodeFontSize,
    this.readOnly = false,
    this.mirroredCaret,
    this.focusNode,
  });

  @override
  State<EditorPane> createState() => _EditorPaneState();

}

class _EditorPaneState extends State<EditorPane> {

  late final CodeLineEditingController _controller = CodeLineEditingController(
    codeLines: widget.text.codeLines,
    spanBuilder: _buildLineSpan,
  );

  /// Stands in when the caller supplies no node. Owned unconditionally so
  /// [_onFocusChanged] has something to listen to either way.
  final FocusNode _ownFocus = FocusNode();

  FocusNode get _focus => widget.focusNode ?? _ownFocus;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  /// Focus can arrive or leave without the text or the selection moving — Tab,
  /// or the playground handing the caret back after a run — and re_editor's
  /// onChanged does not fire for that. Without this the mirror would keep
  /// drawing a caret in a pane nobody is in.
  void _onFocusChanged() => _emit();

  void _emit() {
    // A pane showing someone else's caret has nothing of its own to report.
    if (widget.mirroredCaret != null) return;
    final selection = _controller.selection;
    widget.onChanged(
      _controller.text,
      _focus.hasFocus ? (line: selection.extentIndex, column: selection.extentOffset) : null,
    );
  }

  @override
  void didUpdateWidget(EditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only push text in when it genuinely differs. The config round-trips through
    // the board on every keystroke, so assigning unconditionally would reset the
    // caret to the start mid-word. Differing means it changed elsewhere — a
    // mirrored board, or an undo — and the editor should follow.
    if (widget.text != _controller.text) _controller.text = widget.text;
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus).removeListener(_onFocusChanged);
      _focus.addListener(_onFocusChanged);
    }
    _applyMirroredCaret(oldWidget.mirroredCaret);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _ownFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Moves the editor's own selection to wherever the presenter's caret is.
  ///
  /// The caret is *drawn* by [_buildLineSpan], not by this — but line spans are
  /// only rebuilt during layout, and nothing else here marks the field dirty
  /// when a config update carries a new caret and identical text. Assigning the
  /// selection does, so this is what makes a moving caret actually move.
  void _applyMirroredCaret(CodeCaret? previous) {
    final caret = widget.mirroredCaret;
    if (caret == previous) return;

    if (caret == null) {
      // The presenter has left the pane. Nothing about the text or the caret's
      // position changed, so none of the render object's setters would see a
      // difference and the block would simply stay there. Flipping the affinity
      // is a different selection by `==` at exactly the same place on screen —
      // enough to force the relayout that rebuilds the line without a caret.
      final current = _controller.selection;
      _controller.selection = CodeLineSelection.collapsed(
        index: current.extentIndex,
        offset: current.extentOffset,
        affinity: current.extentAffinity == TextAffinity.downstream
            ? TextAffinity.upstream
            : TextAffinity.downstream,
      );
      return;
    }

    // Clamp: the caret and the text travel as separate fields of one config, and
    // a caret past the end of the text would throw somewhere in painting.
    final line = caret.line.clamp(0, _controller.lineCount - 1);
    final column = caret.column.clamp(0, _controller.codeLines[line].text.length);
    _controller.selection = CodeLineSelection.collapsed(index: line, offset: column);
  }

  /// Hands re_editor the syntax-highlighted line back, with the presenter's
  /// caret drawn into it.
  TextSpan _buildLineSpan({
    required BuildContext context,
    required int index,
    required CodeLine codeLine,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    final caret = widget.mirroredCaret;
    if (caret == null || caret.line != index) return textSpan;

    return spanWithBlockCaret(
      textSpan,
      column: caret.column.clamp(0, codeLine.text.length),
      fallbackStyle: style,
      caretStyle: TextStyle(
        backgroundColor: CodePlaygroundStyle.accent(context),
        color: CodePlaygroundStyle.well,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // re_editor implements DeltaTextInputClient itself rather than wrapping an
    // EditableText, so the board's "is the user typing?" check cannot see it —
    // hence the marker. Without it, typing `l` into a program arms the laser
    // pointer and Backspace deletes the widget being arranged.
    return CanvasTextEditingScope(
      child: DecoratedBox(
        decoration: CodePlaygroundStyle.wellDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kPanelRadius),
          child: CodeEditor(
            controller: _controller,
            focusNode: _focus,
            readOnly: widget.readOnly,
            // The board decides what gets focus — a widget dropped on the canvas
            // must not steal the caret from whatever the user was doing.
            autofocus: false,
            // Long lines wrap rather than scrolling sideways: the pane is a fixed
            // width on the canvas, and a horizontal scrollbar there is a trap.
            wordWrap: true,
            padding: const EdgeInsets.all(kPanelPad),
            // Fires on selection changes as well as edits, which is how the
            // caret reaches a mirror.
            onChanged: (_) => _emit(),
            indicatorBuilder: widget.showLineNumbers
                ? (context, controller, chunkController, notifier) => DefaultCodeLineNumber(
                      controller: controller,
                      notifier: notifier,
                      textStyle: CodePlaygroundStyle.mono(
                        fontSize: widget.fontSize,
                        color: CodePlaygroundStyle.faint,
                      ),
                      focusedTextStyle: CodePlaygroundStyle.mono(
                        fontSize: widget.fontSize,
                        color: CodePlaygroundStyle.secondary,
                      ),
                    )
                : null,
            style: CodeEditorStyle(
              fontSize: widget.fontSize,
              fontFamily: CodePlaygroundStyle.monoFontFamily(),
              textColor: CodePlaygroundStyle.onCard,
              backgroundColor: CodePlaygroundStyle.well,
              cursorColor: CodePlaygroundStyle.accent(context),
              selectionColor: CodePlaygroundStyle.accent(context).withValues(alpha: 0.30),
              // Only the program is code; the input pane is plain text.
              //
              // null rather than a theme with no languages in it. re_editor
              // checks the theme for null and otherwise goes straight to
              // `maxSizes.reduce(min)` over the languages — which on an empty
              // map throws "Bad state: No element" from inside its highlighting
              // isolate. On the web that surfaced as a silently dead worker; on
              // a device it is an unhandled exception.
              codeTheme: widget.highlightPython
                  ? CodeHighlightTheme(
                      languages: {'python': CodeHighlightThemeMode(mode: langPython)},
                      theme: CodePlaygroundStyle.syntaxTheme,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

}

/// Returns [span] with the character at [column] inverted — a block caret drawn
/// into the text rather than blinked over it.
///
/// It has to go in the text: re_editor blinks its own caret only while the
/// editor holds focus, and a mirror must never take focus — on the web viewer
/// that would point a spectator's keyboard at a read-only pane, and with two
/// playgrounds on one board only one could ever show a caret. Inverting the
/// character also carries further across a classroom than a one-pixel bar.
///
/// [fallbackStyle] dresses the stand-in space used when [column] is past the last
/// character, which is where the caret sits at the end of a line and on an empty
/// one. [span] is returned untouched if it holds anything other than [TextSpan]s,
/// since flattening those would drop code from the line — better a missing caret
/// than missing text.
TextSpan spanWithBlockCaret(
  TextSpan span, {
  required int column,
  required TextStyle fallbackStyle,
  required TextStyle caretStyle,
}) {
  final runs = _flatten(span, null);
  if (runs == null) return span;

  final children = <InlineSpan>[];
  var consumed = 0;
  var placed = false;
  for (final run in runs) {
    final text = run.text ?? '';
    final start = consumed;
    consumed += text.length;
    if (placed || column < start || column >= consumed) {
      children.add(run);
      continue;
    }
    final at = column - start;
    placed = true;
    if (at > 0) children.add(TextSpan(text: text.substring(0, at), style: run.style));
    children.add(TextSpan(text: text[at], style: (run.style ?? const TextStyle()).merge(caretStyle)));
    if (at + 1 < text.length) children.add(TextSpan(text: text.substring(at + 1), style: run.style));
  }
  if (!placed) children.add(TextSpan(text: ' ', style: fallbackStyle.merge(caretStyle)));

  return TextSpan(children: children);
}

/// Collapses a span tree into a flat list of styled runs, merging each ancestor's
/// style down into its leaves. Null if it meets a span that is not a [TextSpan],
/// which this cannot represent.
List<TextSpan>? _flatten(TextSpan span, TextStyle? inherited) {
  final style = inherited == null ? span.style : inherited.merge(span.style);
  final runs = <TextSpan>[];
  final text = span.text;
  if (text != null && text.isNotEmpty) runs.add(TextSpan(text: text, style: style));
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is! TextSpan) return null;
    final nested = _flatten(child, style);
    if (nested == null) return null;
    runs.addAll(nested);
  }
  return runs;
}
