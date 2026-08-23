import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_entry.dart';
import 'package:h3xboard/views/components/file_format.dart';
import 'package:h3xboard/views/components/flyouts/app_menu_flyout.dart';
import 'package:h3xboard/views/components/flyouts/continuous_menu_flyout.dart';
import 'package:h3xboard/views/components/flyouts/stable_flyout_controller.dart';
import 'package:h3xboard/views/components/scroll_shadow.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// What a row's overflow menu can ask for. The row reports the intent; the
/// dialog performs it, so there is one place where files are mutated.
enum FileManagerRowAction { rename, move, delete }

/// The left-hand pane of the file manager: the folders and files of one folder,
/// with a checkbox per row.
///
/// The checkboxes are always visible rather than appearing on hover. Multi-select
/// that only exists once you know to hover — or that needs a modifier key — is
/// multi-select that a touch user does not have. Ctrl/Shift still work on top of
/// it for anyone with a keyboard.
class FileManagerList extends StatelessWidget {

  final List<FileManagerEntry> entries;
  final Set<String> selectedIds;

  /// A row was clicked: navigate into a folder, or select a file.
  final void Function(FileManagerEntry entry) onRowPressed;

  /// A row's checkbox was clicked: add to or remove from the selection.
  final void Function(FileManagerEntry entry) onRowChecked;

  final void Function(FileManagerEntry entry, FileManagerRowAction action) onRowAction;

  /// Null while an operation is running, which disables selection changes too —
  /// acting on a selection that shifts under a running delete is how the wrong
  /// file gets deleted.
  final ValueChanged<bool>? onSelectAllChanged;

  final bool enabled;

  const FileManagerList({
    super.key,
    required this.entries,
    required this.selectedIds,
    required this.onRowPressed,
    required this.onRowChecked,
    required this.onRowAction,
    required this.onSelectAllChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    final theme = FluentTheme.of(context);
    final allSelected = entries.isNotEmpty && entries.every((e) => selectedIds.contains(e.selectionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Checkbox(
                checked: entries.isEmpty ? false : (allSelected ? true : (selectedIds.isEmpty ? false : null)),
                onChanged: entries.isEmpty ? null : (value) => onSelectAllChanged?.call(value ?? false),
              ),
              const SizedBox(width: 10),
              Text(
                loc.fileManager_selectAll,
                style: theme.typography.caption?.copyWith(color: theme.resources.textFillColorSecondary),
              ),
              const Spacer(),
              if (selectedIds.isNotEmpty)
                Text(
                  loc.fileManager_selectedCount(selectedIds.length),
                  style: theme.typography.caption?.copyWith(color: theme.resources.textFillColorSecondary),
                ),
            ],
          ),
        ),
        Expanded(
          child: ScrollShadow(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];

                return _EntryRow(
                  key: ValueKey(entry.selectionId),
                  entry: entry,
                  isSelected: selectedIds.contains(entry.selectionId),
                  enabled: enabled,
                  onPressed: () => onRowPressed(entry),
                  onChecked: () => onRowChecked(entry),
                  onAction: (action) => onRowAction(entry, action),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

}

class _EntryRow extends StatefulWidget {

  final FileManagerEntry entry;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback onChecked;
  final ValueChanged<FileManagerRowAction> onAction;

  const _EntryRow({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.enabled,
    required this.onPressed,
    required this.onChecked,
    required this.onAction,
  });

  @override
  State<_EntryRow> createState() => _EntryRowState();

}

class _EntryRowState extends State<_EntryRow> {

  final _flyoutController = StableFlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _showMenu() {
    final loc = context.localizations;
    final destructive = context.appTheme.colors.destructive;
    _flyoutController.showFlyout(
      placementMode: FlyoutPlacementMode.bottomRight,
      builder: (context) => AppMenuFlyout(
        shape: continuousMenuShape(context),
        itemMargin: kMenuItemMargin,
        items: [
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.pencil),
            text: Text(loc.fileManager_rename),
            onPressed: () => _act(context, FileManagerRowAction.rename),
          ),
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.folderInput),
            text: Text(loc.fileManager_move),
            onPressed: () => _act(context, FileManagerRowAction.move),
          ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            leading: Icon(LucideIcons.trash2, color: destructive),
            text: Text(loc.fileManager_delete, style: TextStyle(color: destructive)),
            onPressed: () => _act(context, FileManagerRowAction.delete),
          ),
        ],
      ),
    );
  }

  // A MenuFlyoutItem closes on its own nested navigator. Opening a dialog from
  // inside that pop leaves the barrier stacked over a flyout that is still
  // closing, so the action is deferred to the frame after it is gone.
  void _act(BuildContext flyoutContext, FileManagerRowAction action) {
    Navigator.of(flyoutContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAction(action);
    });
  }

  @override
  Widget build(BuildContext context) {
    return HoverButton(
      onPressed: widget.enabled ? widget.onPressed : null,
      builder: _buildRow,
    );
  }

  Widget _buildRow(BuildContext context, Set<WidgetState> states) {
    final theme = FluentTheme.of(context);
    final appColors = context.appTheme.colors;
    final entry = widget.entry;
    final folder = entry is FolderEntry ? entry : null;
    final file = entry is FileEntry ? entry.file : null;

    // Never lerp from Colors.transparent: that constant is transparent *black*,
    // so an AnimatedContainer fading in a light hover fill passes through dark
    // semi-transparent greys and flashes once on the way. The resting colour is
    // therefore the hover colour at zero alpha — same hue, nothing to travel
    // through.
    final hoverColor = theme.resources.subtleFillColorSecondary;
    final background = widget.isSelected
        ? appColors.selection
        : states.isHovered
            ? hoverColor
            : hoverColor.withValues(alpha: 0);

    // On the accent fill the ordinary body colour is dark-on-blue. The paired
    // foreground lives next to `selection` in the theme so the two cannot drift.
    final foreground = widget.isSelected ? appColors.onSelection : null;
    final secondary = widget.isSelected ? appColors.onSelection : theme.resources.textFillColorSecondary;

    // A checked checkbox is accent-filled, so on a selected row it would be blue
    // on blue. Inverting it reuses the same pair the row's own colours come from
    // rather than introducing a third colour.
    final checkboxStyle = widget.isSelected
        ? CheckboxThemeData(
            checkedDecoration: WidgetStatePropertyAll(
              BoxDecoration(color: appColors.onSelection, borderRadius: BorderRadius.circular(6)),
            ),
            checkedIconColor: WidgetStatePropertyAll(appColors.selection),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.only(left: 8, right: 4),
        height: 44,
        decoration: ShapeDecoration(
          color: background,
          shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(kMenuItemCornerRadius)),
        ),
        child: Row(
          children: [
            Checkbox(
              checked: widget.isSelected,
              style: checkboxStyle,
              onChanged: widget.enabled ? (_) => widget.onChecked() : null,
            ),
            const SizedBox(width: 10),
            Icon(_iconFor(entry), size: 18, color: secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (folder != null ? theme.typography.bodyStrong : theme.typography.body)
                    ?.copyWith(color: foreground),
              ),
            ),
            if (folder?.isPending ?? false)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(LucideIcons.clock, size: 14, color: secondary),
              ),
            if (file != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  formatFileSize(file.sizeBytes),
                  style: theme.typography.caption?.copyWith(color: secondary),
                ),
              ),
            const SizedBox(width: 4),
            FlyoutTarget(
              controller: _flyoutController,
              child: IconButton(
                icon: Icon(LucideIcons.ellipsis, size: 18, color: foreground),
                onPressed: widget.enabled ? _showMenu : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(FileManagerEntry entry) {
    if (entry is FolderEntry) return LucideIcons.folder;
    final contentType = (entry as FileEntry).file.contentType;
    if (contentType.startsWith('image/')) return LucideIcons.image;
    if (contentType.startsWith('audio/')) return LucideIcons.music;

    return LucideIcons.file;
  }

}
