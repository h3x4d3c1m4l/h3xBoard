import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_export.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:scroll_edge_hint/scroll_edge_hint.dart';

/// The parts the export and print dialogs have in common: the quality picker and
/// the sub-board checklist. Both dialogs own the state and hand it down; this is
/// pure presentation.
///
/// The sub-board section hides itself when the board has only one sub-board —
/// there would be nothing to choose.
class ExportOptionsForm extends StatelessWidget {

  final List<Board> subBoards;
  final Set<String> selectedSubBoardIds;
  final ExportQuality quality;
  final ValueChanged<ExportQuality> onQualityChanged;
  final void Function(String id, bool selected) onSubBoardToggled;
  final ValueChanged<bool> onAllSubBoardsToggled;

  const ExportOptionsForm({
    super.key,
    required this.subBoards,
    required this.selectedSubBoardIds,
    required this.quality,
    required this.onQualityChanged,
    required this.onSubBoardToggled,
    required this.onAllSubBoardsToggled,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExportSection(
          icon: LucideIcons.gauge,
          title: loc.exportDialog_quality,
          child: Row(
            children: [
              for (final value in ExportQuality.values) ...[
                if (value != ExportQuality.values.first) const SizedBox(width: 12),
                Expanded(
                  child: ExportOptionTile(
                    icon: switch (value) {
                      ExportQuality.low => LucideIcons.signalLow,
                      ExportQuality.normal => LucideIcons.signalMedium,
                      ExportQuality.high => LucideIcons.signalHigh,
                    },
                    label: _qualityLabel(loc, value),
                    subtitle: loc.exportDialog_qualityResolution(value.width, value.height),
                    isActive: quality == value,
                    onPressed: () => onQualityChanged(value),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (subBoards.length > 1) ...[
          const SizedBox(height: 24),
          ExportSection(
            icon: LucideIcons.layers,
            title: loc.exportDialog_subBoards,
            subtitle: loc.exportDialog_subBoardsSelected(selectedSubBoardIds.length, subBoards.length),
            trailing: Checkbox(
              checked: _allSelected ? true : (selectedSubBoardIds.isEmpty ? false : null),
              onChanged: (_) => onAllSubBoardsToggled(!_allSelected),
              content: Text(loc.exportDialog_selectAll),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ScrollEdgeHint.builder(
                extent: 16,
                backgroundColor: Colors.white,
                builder: (context, controller) => ListView.builder(
                  controller: controller,
                  shrinkWrap: true,
                  itemCount: subBoards.length,
                  itemBuilder: (context, index) {
                    final subBoard = subBoards[index];
                    final selected = selectedSubBoardIds.contains(subBoard.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Checkbox(
                        checked: selected,
                        onChanged: (value) => onSubBoardToggled(subBoard.id, value ?? false),
                        content: Text(subBoard.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool get _allSelected => selectedSubBoardIds.length == subBoards.length;

  String _qualityLabel(AppLocalizations loc, ExportQuality value) => switch (value) {
        ExportQuality.low => loc.exportDialog_qualityLow,
        ExportQuality.normal => loc.exportDialog_qualityNormal,
        ExportQuality.high => loc.exportDialog_qualityHigh,
      };

}

/// The export/print dialog header: title + subtitle on the left, close on the
/// right — same shape as the board settings and widget catalog headers.
class ExportDialogHeader extends StatelessWidget {

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const ExportDialogHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.typography.subtitle),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.typography.body?.copyWith(color: theme.resources.textFillColorSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.x, size: 18),
          onPressed: onClose,
        ),
      ],
    );
  }

}

/// A labelled section in the export/print dialogs: an accent-tinted icon + title
/// (with an optional [trailing] control) above its [child]. Mirrors the board
/// settings dialog's section styling so all three dialogs read the same.
class ExportSection extends StatelessWidget {

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const ExportSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: theme.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.typography.bodyStrong),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.typography.caption?.copyWith(color: theme.resources.textFillColorSecondary),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

}

/// A selectable tile — icon, label and a caption — used for both the format and
/// the quality choice. Same look as the board settings dialog's pattern tiles.
class ExportOptionTile extends StatelessWidget {

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isActive;
  final VoidCallback onPressed;

  const ExportOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        final highlighted = isActive || states.isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? theme.accentColor.withValues(alpha: 0.08) : theme.resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: highlighted ? theme.accentColor : theme.resources.controlStrokeColorDefault,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: isActive ? theme.accentColor : null),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body?.copyWith(fontWeight: isActive ? FontWeight.bold : null),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption?.copyWith(color: theme.resources.textFillColorSecondary),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

}
