import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_breadcrumb.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_paths.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_prompts.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:h3xboard/views/components/scroll_shadow.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Asks which folder to move the selection into. Returns the destination path
/// ("" for the root), or `null` when dismissed.
///
/// It browses rather than drawing a tree, because a tree would need one
/// `files.v1.browse` per folder up front just to render — the same cost the
/// manager itself avoids by loading a folder at a time.
///
/// [blockedPaths] are folders the selection cannot land in: the folders being
/// moved themselves. Moving a folder inside itself would rewrite its files to
/// paths under a folder that no longer exists at the old address, and there is
/// no folder API to repair that with.
Future<String?> showFolderPickerDialog(
  BuildContext context, {
  required H3xBoardApiClient apiClient,
  required String initialPath,
  Set<String> blockedPaths = const {},
}) {
  return showAppDialog<String>(
    context: context,
    barrierDismissible: true,
    useRootNavigator: false,
    builder: (_) => _FolderPickerDialog(
      apiClient: apiClient,
      initialPath: initialPath,
      blockedPaths: blockedPaths,
    ),
  );
}

class _FolderPickerDialog extends StatefulWidget {

  final H3xBoardApiClient apiClient;
  final String initialPath;
  final Set<String> blockedPaths;

  const _FolderPickerDialog({
    required this.apiClient,
    required this.initialPath,
    required this.blockedPaths,
  });

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();

}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {

  late String _path = widget.initialPath;
  List<String>? _folders;
  bool _loadError = false;

  /// Folders created here but not yet given a file — same rule as the manager's
  /// own pending folders, and the reason "move into a brand new folder" works at
  /// all: the move itself is what creates the folder server-side.
  final Set<String> _pending = {};

  @override
  void initState() {
    super.initState();
    _load(_path);
  }

  Future<void> _load(String path) async {
    setState(() {
      _path = path;
      _folders = null;
      _loadError = false;
    });
    try {
      final result = await widget.apiClient.browseFiles(path);
      if (!mounted) return;
      setState(() => _folders = _mergePending(result.folders));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  List<String> _mergePending(List<String> serverFolders) {
    final names = {
      ...serverFolders,
      ..._pending.where((p) => folderSegments(p).length == folderSegments(_path).length + 1 && isInFolder(p, _path)).map(folderDisplayName),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return names;
  }

  Future<void> _createFolder() async {
    final name = await showNamePromptDialog(
      context,
      title: context.localizations.fileManager_newFolderTitle,
      initialValue: '',
      confirmLabel: context.localizations.fileManager_create,
      validate: folderNameValidator(_folders ?? const []),
    );
    if (name == null || !mounted) return;

    final path = joinFolderPath(_path, name);
    setState(() => _pending.add(path));
    await _load(path);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    final folders = _folders;
    final isBlocked = widget.blockedPaths.any((blocked) => isInFolder(_path, blocked));

    return ThemableContentDialog(
      title: Text(loc.fileManager_moveTitle),
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
      scrollableContent: false,
      content: SizedBox(
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FileManagerBreadcrumb(path: _path, onNavigate: _load),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(loc, folders)),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => unawaited(_createFolder()),
          child: Text(loc.fileManager_newFolder),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.fileManager_cancel),
        ),
        FilledButton(
          onPressed: isBlocked ? null : () => Navigator.of(context).pop(_path),
          child: Text(loc.fileManager_moveHere),
        ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations loc, List<String>? folders) {
    if (_loadError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.fileManager_loadError),
            const SizedBox(height: 12),
            Button(onPressed: () => _load(_path), child: Text(loc.fileManager_retry)),
          ],
        ),
      );
    }
    if (folders == null) return const Center(child: ProgressRing());

    return ScrollShadow(
      child: ListView.builder(
        itemCount: folders.length,
        itemBuilder: (context, index) {
          final name = folders[index];
          final path = joinFolderPath(_path, name);
          final blocked = widget.blockedPaths.any((b) => isInFolder(path, b));

          return HoverButton(
            onPressed: blocked ? null : () => _load(path),
            builder: (context, states) => Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: states.isHovered ? FluentTheme.of(context).resources.cardBackgroundFillColorDefault : null,
              child: Row(
                children: [
                  const Icon(LucideIcons.folder, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Opacity(
                      opacity: blocked ? 0.4 : 1,
                      child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}
