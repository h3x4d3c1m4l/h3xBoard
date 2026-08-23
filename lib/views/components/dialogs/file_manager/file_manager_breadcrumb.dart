import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_paths.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Where you are in the virtual folder tree, and the way back out.
///
/// Shared by the file manager and its move-to-folder picker so the two read the
/// same, which matters more than usual here: the picker is the manager's own
/// folder list shown a second time, and a different-looking path would suggest a
/// different tree.
class FileManagerBreadcrumb extends StatelessWidget {

  final String path;
  final ValueChanged<String> onNavigate;

  const FileManagerBreadcrumb({super.key, required this.path, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    final segments = folderSegments(path);

    final crumbs = <Widget>[
      if (segments.isEmpty) _Current(loc.fileManager_home) else _link(loc.fileManager_home, ''),
    ];

    var walked = '';
    for (var i = 0; i < segments.length; i++) {
      walked = joinFolderPath(walked, segments[i]);
      final isLast = i == segments.length - 1;
      crumbs
        ..add(const Icon(LucideIcons.chevronRight, size: 14))
        ..add(isLast ? _Current(segments[i]) : _link(segments[i], walked));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: crumbs),
    );
  }

  Widget _link(String label, String target) => HyperlinkButton(
        onPressed: () => onNavigate(target),
        child: Text(label),
      );

}

/// The crumb for the folder you are already in.
///
/// Plain text, not a disabled [HyperlinkButton]. Fluent paints a disabled button
/// in `textFillColorDisabled` — a pale grey that all but vanishes against the
/// dialog's patterned surface. And the crumb is not a dead control in the first
/// place: it is the label for where you are, so it reads as one.
///
/// It borrows the button padding rather than choosing its own, so it stays on
/// the same baseline and rhythm as the links beside it however that style moves.
class _Current extends StatelessWidget {

  final String label;

  const _Current(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: kControlPadding,
      child: Text(label, style: FluentTheme.of(context).typography.bodyStrong),
    );
  }

}
