import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/programming_language.dart';
import 'package:h3xboard/services/python/python_runtime.dart';
import 'package:h3xboard/views/board_screen/components/board_mirror_scope.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_metrics.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_style.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/components/editor_pane.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/components/output_panel.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Write a short program, run it, and show a class what came out.
///
/// The code, the input and the last run's output all live in the board config, so
/// they mirror to the external display and to web viewers and survive a reload.
/// The program itself only runs on the device being edited — a mirror renders the
/// last result and never executes anything, which falls out of `onChanged` being
/// a no-op there.
class CodePlaygroundWidget extends StatefulWidget {

  final CodePlaygroundConfig config;
  final ValueChanged<CodePlaygroundConfig> onChanged;

  /// Stands in for the real interpreter in tests. Without it the run path is
  /// untestable off the web, since the stub runtime disables the button.
  @visibleForTesting
  final PythonRuntime? debugRuntime;

  const CodePlaygroundWidget({
    super.key,
    required this.config,
    required this.onChanged,
    this.debugRuntime,
  });

  @override
  State<CodePlaygroundWidget> createState() => _CodePlaygroundWidgetState();

}

class _CodePlaygroundWidgetState extends State<CodePlaygroundWidget> {

  /// Created lazily: a board full of playgrounds should not spin up an
  /// interpreter each until someone actually presses Run.
  PythonRuntime? _runtime;
  bool _isRunning = false;

  /// Owned here so the caret can be handed back to the code pane after a run,
  /// rather than making the user click into it again.
  final FocusNode _codeFocus = FocusNode(debugLabel: 'code playground editor');

  PythonRuntime get runtime => _runtime ??= widget.debugRuntime ?? createPythonRuntime();

  @override
  void dispose() {
    _codeFocus.dispose();
    _runtime?.dispose();
    super.dispose();
  }

  /// Publishes a config, unless nothing actually moved.
  ///
  /// The panes report their text and caret together on every notification, so
  /// plenty of those carry no change at all — and an identical config would
  /// still be treated as a board edit and take an undo slot, because
  /// `isWidgetRuntimeOnlyChange` only recognises configs that *differ*.
  void _apply(CodePlaygroundConfig updated) {
    if (updated != widget.config) widget.onChanged(updated);
  }

  /// Puts the caret back where the user was working, once the run has settled.
  void _returnFocusToEditor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codeFocus.requestFocus();
    });
  }

  Future<void> _run() async {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    final result = await runtime.run(widget.config.code, stdin: widget.config.stdinText);

    if (!mounted) return;
    setState(() => _isRunning = false);
    widget.onChanged(widget.config.copyWith(
      stdout: result.stdout,
      stderr: result.stderr,
      exitCode: result.exitCode,
      outputTruncated: result.truncated,
      durationMs: result.duration.inMilliseconds,
    ));
    _returnFocusToEditor();
  }

  Future<void> _stop() async {
    await runtime.cancel();
    if (!mounted) return;
    setState(() => _isRunning = false);
    _returnFocusToEditor();
  }

  @override
  Widget build(BuildContext context) {
    // On the external display and for web viewers this widget is a picture of
    // someone else's playground. Everything that operates it goes quiet: an
    // editable pane there takes typing and then loses it to the presenter's next
    // update, and Run would execute the program on the wrong machine.
    final isMirror = BoardMirrorScope.isMirror(context);
    final caret = widget.config.caretLine;
    final caretColumn = widget.config.caretColumn;

    return SizedBox(
      width: kCardWidth,
      height: kCardHeight,
      child: DecoratedBox(
        decoration: CodePlaygroundStyle.cardDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kCardPadH, vertical: kCardPadV),
          child: Column(
            children: [
              _buildToolbar(context, isMirror),
              const SizedBox(height: kSectionGap),
              SizedBox(
                height: kEditorHeight,
                child: EditorPane(
                  text: widget.config.code,
                  focusNode: _codeFocus,
                  highlightPython: widget.config.language == ProgrammingLanguage.python,
                  showLineNumbers: true,
                  readOnly: isMirror,
                  mirroredCaret: isMirror && caret != null && caretColumn != null
                      ? (line: caret, column: caretColumn)
                      : null,
                  onChanged: (code, caret) => _apply(widget.config.copyWith(
                    code: code,
                    caretLine: caret?.line,
                    caretColumn: caret?.column,
                  )),
                ),
              ),
              const SizedBox(height: kSectionGap),
              SizedBox(height: kIoHeight, child: _buildIoRow(context, isMirror)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, bool isMirror) {
    final loc = context.localizations;
    // Asking the runtime would build one, and a mirror has no business starting
    // an interpreter for a program it will never run.
    final canRun = !isMirror && runtime.isSupported;

    return SizedBox(
      height: kToolbarHeight,
      child: ButtonTheme.merge(
        data: CodePlaygroundStyle.buttonTheme(context),
        child: Row(
          children: [
            _buildLanguageChip(context),
            const Spacer(),
            // Flexible, not fixed: this string is the longest thing on the row
            // and its length varies by translation, so it yields to the buttons
            // rather than pushing them off the card. Not on a mirror: "run it in
            // the web app" is no help to someone watching a projector, and the
            // greyed-out button already says enough.
            if (!canRun && !isMirror)
              Flexible(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Text(
                    loc.codePlayground_runUnavailable,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: CodePlaygroundStyle.label(
                      fontSize: kLabelFontSize,
                      color: CodePlaygroundStyle.muted,
                    ),
                  ),
                ),
              ),
            // Deliberately one button that changes, rather than two swapped by
            // the running state. Swapping widget *types* here remounts the
            // subtree and disposes the button's focus node mid-run, which is
            // enough to leave focus nowhere and make the editor silently ignore
            // every keystroke afterwards.
            FilledButton(
              style: _isRunning
                  ? ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(CodePlaygroundStyle.error),
                    )
                  : null,
              onPressed: canRun ? () => unawaited(_isRunning ? _stop() : _run()) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Icon(_isRunning ? LucideIcons.square : LucideIcons.play, size: 16),
                  Text(
                    _isRunning ? loc.codePlayground_stop : loc.codePlayground_run,
                    style: CodePlaygroundStyle.label(
                      fontSize: kToolbarFontSize,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0B1220),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reads "Python 3.14.7". Which version is running is not a detail when the
  /// point is teaching — a pupil comparing against docs needs to know.
  ///
  /// A menu rather than a label because more languages are the plan; with one
  /// entry it still shows what is selected and what the alternatives are (none,
  /// for now).
  Widget _buildLanguageChip(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: CodePlaygroundStyle.wellDecoration(),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Icon(LucideIcons.code, size: 16, color: CodePlaygroundStyle.accent(context)),
          Text(
            widget.config.language.label,
            style: CodePlaygroundStyle.label(
              fontSize: kToolbarFontSize,
              fontWeight: FontWeight.w600,
              color: CodePlaygroundStyle.onCard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIoRow(BuildContext context, bool isMirror) {
    final loc = context.localizations;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: kInputFlex,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: kPanelLabelHeight,
                child: Text(loc.codePlayground_input.toUpperCase(),
                    style: CodePlaygroundStyle.caption()),
              ),
              const SizedBox(height: kPanelLabelGap),
              Expanded(
                child: EditorPane(
                  text: widget.config.stdinText,
                  fontSize: kOutputFontSize,
                  readOnly: isMirror,
                  // The caret is ignored here: only the program's is mirrored,
                  // since that is where a class is being shown something.
                  onChanged: (text, _) => _apply(widget.config.copyWith(stdinText: text)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: kIoGap),
        Expanded(
          flex: kOutputFlex,
          child: OutputPanel(config: widget.config, isRunning: _isRunning),
        ),
      ],
    );
  }

}

class CodePlaygroundWidgetDescriptor extends BoardWidgetDescriptor {

  static const CodePlaygroundWidgetDescriptor instance = CodePlaygroundWidgetDescriptor._();
  const CodePlaygroundWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.terminal;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_codePlayground;

  @override
  Size naturalSize(BoardWidgetConfig config) => const Size(kCardWidth, kCardHeight);

  @override
  BoardWidgetConfig get defaultConfig => const CodePlaygroundConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    return CodePlaygroundWidget(
      config: config as CodePlaygroundConfig,
      onChanged: onConfigChanged,
    );
  }

  // Nothing to hide in a flyout: the language and Run/Stop are on the widget's
  // face where a class can see them being used. board.dart still appends layers,
  // visibility and delete.
  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) =>
      const [];

}
