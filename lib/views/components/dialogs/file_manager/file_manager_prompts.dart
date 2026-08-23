import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_paths.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';

/// The small dialogs the file manager asks its questions with: a name prompt and
/// a destructive confirmation.
///
/// Every one of them is opened from inside the file manager, which is itself a
/// dialog on a non-root navigator, so they all pass `useRootNavigator: false`.
/// A root-level barrier would stack over the manager and dim it.

/// Asks for a new name, seeded with [initialValue] and validated as the user
/// types. Returns the trimmed name, or `null` when dismissed or unchanged.
///
/// [validate] returns the error to show, or `null` when the name is usable. It
/// runs on every keystroke so the OK button can be disabled rather than letting
/// the user submit a name the server will refuse.
Future<String?> showNamePromptDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required String confirmLabel,
  String? Function(String name, AppLocalizations loc)? validate,
}) async {
  final controller = TextEditingController(text: initialValue)
    ..selection = TextSelection(baseOffset: 0, extentOffset: initialValue.length);
  try {
    final name = await showAppDialog<String>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: false,
      builder: (ctx) => _NamePrompt(
        title: title,
        confirmLabel: confirmLabel,
        controller: controller,
        validate: validate,
      ),
    );
    if (name == null || name == initialValue) return null;

    return name;
  } finally {
    controller.dispose();
  }
}

/// The validator [showNamePromptDialog] takes for a *folder* name, turning the
/// locale-independent [folderNameProblem] rule into something to read.
String? Function(String, AppLocalizations) folderNameValidator(Iterable<String> siblings) {
  return (name, loc) => switch (folderNameProblem(name, siblings: siblings)) {
        FolderNameProblem.empty => loc.fileManager_folderNameEmpty,
        FolderNameProblem.invalidCharacters => loc.fileManager_folderNameInvalid,
        FolderNameProblem.duplicate => loc.fileManager_folderNameDuplicate,
        null => null,
      };
}

/// The validator for a *file* name. A file name may contain almost anything, so
/// the only rule is that it is not blank — a rename to "" would leave a row with
/// nothing to click on.
String? fileNameValidator(String name, AppLocalizations loc) =>
    name.trim().isEmpty ? loc.fileManager_folderNameEmpty : null;

/// Confirms a deletion. Returns `true` only on an explicit confirmation.
///
/// [message] describes what goes; [warning] is the standing caveat that a board
/// still pointing at a deleted file will stop showing it — there is no way to
/// check that from the client, so it is said every time rather than only when
/// it applies.
Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final loc = context.localizations;
  final confirmed = await showAppDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => ThemableContentDialog(
      severity: ThemableDialogSeverity.error,
      title: Text(title),
      constraints: const BoxConstraints(maxWidth: 460),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          Text(
            loc.fileManager_deleteInUseWarning,
            style: FluentTheme.of(ctx).typography.caption,
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(loc.fileManager_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(loc.fileManager_delete),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

class _NamePrompt extends StatefulWidget {

  final String title;
  final String confirmLabel;
  final TextEditingController controller;
  final String? Function(String name, AppLocalizations loc)? validate;

  const _NamePrompt({
    required this.title,
    required this.confirmLabel,
    required this.controller,
    required this.validate,
  });

  @override
  State<_NamePrompt> createState() => _NamePromptState();

}

class _NamePromptState extends State<_NamePrompt> {

  String? _error;

  /// Whether the field has been edited. A blank "New folder" prompt is invalid
  /// the moment it opens, but scolding someone before they have typed anything
  /// is noise — the disabled OK button already says the name is not usable yet.
  bool _touched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: reading localizations is an inherited-widget lookup, which
    // is only legal once dependencies are resolved.
    _error = widget.validate?.call(widget.controller.text, context.localizations);
  }

  void _onChanged(String value) {
    final error = widget.validate?.call(value, context.localizations);
    if (error != _error || !_touched) {
      setState(() {
        _error = error;
        _touched = true;
      });
    }
  }

  void _submit() {
    if (_error != null) return;
    Navigator.of(context).pop(widget.controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return ThemableContentDialog(
      title: Text(widget.title),
      constraints: const BoxConstraints(maxWidth: 460),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ContinuousTextBox(
            controller: widget.controller,
            placeholder: loc.fileManager_nameLabel,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: _onChanged,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null && _touched) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: ThemableDialogSeverity.error.primaryColor,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.fileManager_cancel),
        ),
        FilledButton(
          onPressed: _error == null ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

}
