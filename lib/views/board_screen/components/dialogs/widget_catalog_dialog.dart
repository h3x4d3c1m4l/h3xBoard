import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/themable_panel_dialog.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:scroll_edge_hint/scroll_edge_hint.dart';

/// The "Add a widget" catalog. Shows every registered widget type rendered with
/// its default config as a live preview, ordered alphabetically by label and
/// filterable by a search box. Pops the chosen [BoardWidgetConfig] (the
/// descriptor's [BoardWidgetDescriptor.defaultConfig]) so the caller can add it
/// to the board, or `null` when dismissed.
class WidgetCatalogDialog extends StatefulWidget {

  const WidgetCatalogDialog({super.key});

  @override
  State<WidgetCatalogDialog> createState() => _WidgetCatalogDialogState();

}

class _WidgetCatalogDialogState extends State<WidgetCatalogDialog> {

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _query = _searchController.text.trim()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _select(BoardWidgetConfig config) => Navigator.of(context).pop(config);

  // All descriptors ordered alphabetically by their localized label, narrowed to
  // those whose label contains the (case-insensitive) search query.
  List<BoardWidgetDescriptor> _visibleDescriptors(AppLocalizations loc) {
    final query = _query.toLowerCase();
    final descriptors = widgetRegistry.values.toList()
      ..sort((a, b) => a.label(loc).toLowerCase().compareTo(b.label(loc).toLowerCase()));
    if (query.isEmpty) return descriptors;
    return descriptors.where((d) => d.label(loc).toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    final descriptors = _visibleDescriptors(loc);

    return ThemablePanelDialog(
      constraints: const BoxConstraints(maxWidth: 920, maxHeight: 820),
      content: SizedBox(
        height: 760,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: loc.widgetCatalog_title,
                subtitle: loc.widgetCatalog_subtitle,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              ContinuousTextBox(
                controller: _searchController,
                placeholder: loc.widgetCatalog_search,
              ),
              const SizedBox(height: 24),
              Text(
                loc.widgetCatalog_allWidgets,
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: descriptors.isEmpty
                    ? Center(child: Text(loc.widgetCatalog_noResults))
                    // Fade the grid at its scrollable top/bottom edges to hint
                    // that there's more content. backgroundColor matches the
                    // dialog's white surface so rows dissolve into the edge.
                    : ScrollEdgeHint.builder(
                        extent: 24,
                        backgroundColor: Colors.white,
                        builder: (context, controller) => GridView.builder(
                          controller: controller,
                          padding: const EdgeInsets.only(right: 4),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 1.15,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: descriptors.length,
                          itemBuilder: (context, index) {
                            final descriptor = descriptors[index];
                            return _WidgetTile(
                              descriptor: descriptor,
                              onPressed: () => _select(descriptor.defaultConfig),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// The catalog header: title + subtitle on the left, a close button on the right.
class _Header extends StatelessWidget {

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const _Header({required this.title, required this.subtitle, required this.onClose});

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

/// One catalog tile: a live preview of the widget (rendered with its default
/// config, padded and scaled to fit via [FittedBox]) above its label. The whole
/// tile is a button; the preview is wrapped in [IgnorePointer] so interactive
/// widgets (piano keys, traffic lights, …) don't swallow the tap.
class _WidgetTile extends StatelessWidget {

  final BoardWidgetDescriptor descriptor;
  final VoidCallback onPressed;

  const _WidgetTile({required this.descriptor, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final loc = context.localizations;
    final size = descriptor.naturalSize(descriptor.defaultConfig);

    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: theme.resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: states.isHovered
                  ? theme.accentColor.withValues(alpha: 0.5)
                  : theme.resources.controlStrokeColorDefault,
              width: states.isHovered ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: theme.resources.cardBackgroundFillColorSecondary,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: IgnorePointer(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox.fromSize(
                          size: size,
                          child: descriptor.buildWidget(descriptor.defaultConfig, (_) {}),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.resources.controlStrokeColorDefault)),
                ),
                child: Text(
                  descriptor.label(loc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.bodyStrong,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
