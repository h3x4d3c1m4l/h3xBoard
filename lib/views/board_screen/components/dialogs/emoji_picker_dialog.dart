import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/services/emoji/emoji_pack_store.dart';
import 'package:h3xboard/services/emoji/emoji_repository.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/themable_panel_dialog.dart';
import 'package:h3xboard/views/board_screen/components/widgets/emoji_image.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:scroll_edge_hint/scroll_edge_hint.dart';

/// Number of emoji per row. Fixed rather than derived from a maximum tile width
/// so section offsets can be computed exactly for the category jump — see
/// [_EmojiGridState._offsetOfGroup].
const int _columns = 9;

/// Height of a category heading in the grid.
const double _headerHeight = 34;

/// Picks one emoji out of the complete Unicode set, returning its characters
/// (skin-tone modifier included) or `null` when dismissed.
///
/// Emoji are grouped and ordered exactly as Unicode orders them, searchable by
/// their CLDR name and keywords in the app's language, and rendered from the
/// same bundled vector artwork the board uses.
class EmojiPickerDialog extends StatefulWidget {

  /// The emoji currently on the widget, highlighted in the grid.
  final String selected;

  const EmojiPickerDialog({super.key, required this.selected});

  @override
  State<EmojiPickerDialog> createState() => _EmojiPickerDialogState();

}

class _EmojiPickerDialogState extends State<EmojiPickerDialog> {

  final TextEditingController _searchController = TextEditingController();
  final AppSettingsController _settings = GetIt.I<AppSettingsController>();

  /// Artwork for the grid comes from one packed asset per category rather than
  /// a file per emoji — see [EmojiPackStore] for why. Built in
  /// [didChangeDependencies], since it needs the ambient asset bundle.
  EmojiPackStore? _packs;

  late Future<EmojiCatalog> _catalog;
  String _query = '';
  late EmojiSkinTone _tone = _settings.emojiSkinTone;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _query = _searchController.text.trim()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Loaded per language so search matches what the user reads. Resolved here
    // rather than in initState because the locale is an inherited dependency;
    // [EmojiCatalog.load] caches per locale, so repeat calls are free.
    _catalog = EmojiCatalog.load(Localizations.localeOf(context).languageCode);
    _packs ??= EmojiPackStore(DefaultAssetBundle.of(context));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _packs?.dispose();
    super.dispose();
  }

  void _selectTone(EmojiSkinTone tone) {
    setState(() => _tone = tone);
    // Fire-and-forget, like the laser colour: a failed write must not undo the
    // tone the user just picked.
    _settings.setEmojiSkinTone(tone);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return ThemablePanelDialog(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
      content: SizedBox(
        height: 660,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: FutureBuilder<EmojiCatalog>(
            future: _catalog,
            builder: (context, snapshot) {
              final catalog = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    title: loc.emojiPicker_title,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ContinuousTextBox(
                          controller: _searchController,
                          autofocus: true,
                          placeholder: loc.emojiPicker_search,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _SkinToneStrip(selected: _tone, onChanged: _selectTone),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: catalog == null
                        ? const Center(child: ProgressRing())
                        : _EmojiGrid(
                            catalog: catalog,
                            packs: _packs!,
                            query: _query,
                            tone: _tone,
                            selected: widget.selected,
                            onPicked: (emoji) => Navigator.of(context).pop(emoji),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

}

/// The dialog header: title on the left, close button on the right.
class _Header extends StatelessWidget {

  final String title;
  final VoidCallback onClose;

  const _Header({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(title, style: FluentTheme.of(context).typography.subtitle)),
        IconButton(
          icon: const Icon(LucideIcons.x, size: 18),
          onPressed: onClose,
        ),
      ],
    );
  }

}

/// The six skin-tone choices as a compact strip of swatches.
///
/// Shown inline rather than behind a flyout: it is six small targets, and having
/// them visible makes it obvious the picker *has* skin tones at all.
class _SkinToneStrip extends StatelessWidget {

  final EmojiSkinTone selected;
  final ValueChanged<EmojiSkinTone> onChanged;

  const _SkinToneStrip({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tone in EmojiSkinTone.values)
          Tooltip(
            message: tone.label(loc),
            child: HoverButton(
              onPressed: () => onChanged(tone),
              builder: (context, states) {
                final isSelected = tone == selected;
                return Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.appTheme.colors.selection.withValues(alpha: 0.16)
                        : states.isHovered
                            ? FluentTheme.of(context).resources.subtleFillColorSecondary
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? context.appTheme.colors.selection : Colors.transparent,
                    ),
                  ),
                  child: EmojiImage(emoji: tone.sample),
                );
              },
            ),
          ),
      ],
    );
  }

}

/// The scrolling emoji grid: category sections in Unicode order, or a single
/// flat list of results while searching.
class _EmojiGrid extends StatefulWidget {

  final EmojiCatalog catalog;
  final EmojiPackStore packs;
  final String query;
  final EmojiSkinTone tone;
  final String selected;
  final ValueChanged<String> onPicked;

  const _EmojiGrid({
    required this.catalog,
    required this.packs,
    required this.query,
    required this.tone,
    required this.selected,
    required this.onPicked,
  });

  @override
  State<_EmojiGrid> createState() => _EmojiGridState();

}

class _EmojiGridState extends State<_EmojiGrid> {

  final ScrollController _scrollController = ScrollController();

  /// Cached so a rebuild (e.g. changing skin tone) doesn't re-run the search.
  List<EmojiEntry>? _results;
  String _resultsQuery = '';

  /// Which category tab reads as current, driven by the scroll position.
  int _activeGroup = 0;

  /// Tile edge length, known only once the grid has been laid out.
  double _tileExtent = 0;

  /// Height of the scrolling area, used to work out which categories are on
  /// screen and therefore which packs to pull.
  double _viewportHeight = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncActiveGroup);
  }

  @override
  void didUpdateWidget(_EmojiGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changing the tone changes which packs are needed. Without this the grid
    // sits empty until some other event happens to re-run the calculation —
    // which in practice meant the emoji only came back once you scrolled.
    if (widget.tone != oldWidget.tone) _requestVisiblePacks();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncActiveGroup);
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isSearching => widget.query.isNotEmpty;

  /// Whether the category filling the viewport can be drawn yet. Drives the
  /// spinner: without one, switching tone just blanks the grid with no hint that
  /// anything is happening.
  bool get _isActiveGroupReady =>
      _isSearching ||
      _activeGroup >= widget.catalog.groups.length ||
      widget.packs.isLoaded(widget.catalog.groups[_activeGroup], widget.tone);

  List<EmojiEntry> get _searchResults {
    if (_results == null || _resultsQuery != widget.query) {
      _resultsQuery = widget.query;
      _results = widget.catalog.search(widget.query);
    }
    return _results!;
  }

  /// Scroll offset at which [index]'s section starts. Exact because the column
  /// count is fixed, so every section's height is known without laying it out.
  double _offsetOfGroup(int index) {
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      final rows = (widget.catalog.groups[i].emoji.length / _columns).ceil();
      offset += _headerHeight + rows * _tileExtent;
    }
    return offset;
  }

  void _syncActiveGroup() {
    if (_isSearching || _tileExtent == 0) return;
    // The section whose start is the last one at or above the viewport top.
    var active = 0;
    for (var i = 0; i < widget.catalog.groups.length; i++) {
      if (_offsetOfGroup(i) <= _scrollController.offset + 1) active = i;
    }
    if (active != _activeGroup) setState(() => _activeGroup = active);
    _requestVisiblePacks();
  }

  /// Pulls the packs for the categories currently on screen, and only those.
  ///
  /// Driven from the scroll position rather than from tile builds: the slivers
  /// build a probe child per category regardless of where it sits, so keying off
  /// that would fetch every pack at once.
  void _requestVisiblePacks() {
    if (_tileExtent == 0 || _viewportHeight == 0) return;
    final top = _scrollController.hasClients ? _scrollController.offset : 0.0;
    // A screen of slack either way, so a pack is in flight before its rows are
    // scrolled into view rather than after.
    final start = top - _viewportHeight;
    final end = top + _viewportHeight * 2;

    for (var i = 0; i < widget.catalog.groups.length; i++) {
      final groupTop = _offsetOfGroup(i);
      final rows = (widget.catalog.groups[i].emoji.length / _columns).ceil();
      final groupBottom = groupTop + _headerHeight + rows * _tileExtent;
      if (groupBottom >= start && groupTop <= end) {
        widget.packs.request(widget.catalog.groups[i], widget.tone);
      }
    }
  }

  void _jumpToGroup(int index) {
    _scrollController.animateTo(
      // Clamped, or the last (short) section can't reach the top of the viewport.
      math.min(_offsetOfGroup(index), _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    setState(() => _activeGroup = index);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isSearching) ...[
          _CategoryTabs(
            groups: [for (final group in widget.catalog.groups) group.id],
            active: _activeGroup,
            onSelected: _jumpToGroup,
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // ScrollEdgeHint's fade sits over the grid, so the tile size has to
              // come from the constraints rather than from the scroll view.
              final tileExtent = constraints.maxWidth / _columns;
              if (tileExtent != _tileExtent || constraints.maxHeight != _viewportHeight) {
                _tileExtent = tileExtent;
                _viewportHeight = constraints.maxHeight;
                // Offsets shift when the tile size does; re-derive after layout.
                // This is also what pulls the first visible packs on open.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _syncActiveGroup();
                });
              }

              if (_isSearching && _searchResults.isEmpty) {
                return Center(child: Text(loc.emojiPicker_noResults));
              }

              // The builder form makes its own controller; this grid needs to
              // drive the scroll position itself for the category jump, so it
              // hands its own controller to both.
              // The builder form makes its own controller; this grid needs to
              // drive the scroll position itself for the category jump, so it
              // hands its own controller to both.
              return ListenableBuilder(
                listenable: widget.packs,
                // Tiles stay blank until their category's artwork has arrived, so
                // the grid rebuilds as each pack lands.
                builder: (context, _) => Stack(
                  children: [
                    ScrollEdgeHint(
                      extent: 24,
                      backgroundColor: context.appTheme.dialogs.panelSurfaceColor,
                      controller: _scrollController,
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: _isSearching ? _searchSlivers() : _groupSlivers(loc),
                      ),
                    ),
                    if (!_isActiveGroupReady) const Positioned.fill(child: Center(child: ProgressRing())),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Results span every category, so packing them would mean pulling all nine
  // packs to show a handful of hits. They load individually instead — the grid
  // only builds what is on screen, so a search costs a bounded number of fetches.
  List<Widget> _searchSlivers() => [_grid(_searchResults, null)];

  List<Widget> _groupSlivers(AppLocalizations loc) {
    return [
      for (final group in widget.catalog.groups) ...[
        SliverToBoxAdapter(
          child: SizedBox(
            height: _headerHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                group.id.label(loc),
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
            ),
          ),
        ),
        _grid(group.emoji, group),
      ],
    ];
  }

  /// [group] names the pack the artwork comes from, or null to load each emoji's
  /// own asset (search results, which span categories).
  Widget _grid(List<EmojiEntry> entries, EmojiGroup? group) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _columns),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = entries[index];
          final emoji = entry.withTone(widget.tone);
          // Blank until the category's pack lands; once it has, anything the pack
          // doesn't carry (the toned variants) falls back to its own asset.
          final isReady = group == null || widget.packs.isLoaded(group, widget.tone);
          final loader = group == null ? null : widget.packs.loaderFor(group, emoji, widget.tone);
          return _EmojiTile(
            name: entry.name,
            isSelected: emoji == widget.selected,
            onPressed: () => widget.onPicked(emoji),
            child: isReady ? EmojiImage(emoji: emoji, loader: loader) : const SizedBox.shrink(),
          );
        },
        childCount: entries.length,
      ),
    );
  }

}

/// The category tab strip: one icon per Unicode group, jumping the grid to it.
class _CategoryTabs extends StatelessWidget {

  final List<EmojiGroupId> groups;
  final int active;
  final ValueChanged<int> onSelected;

  const _CategoryTabs({required this.groups, required this.active, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        for (var i = 0; i < groups.length; i++)
          Expanded(
            child: Tooltip(
              message: groups[i].label(loc),
              child: HoverButton(
                onPressed: () => onSelected(i),
                builder: (context, states) {
                  final isActive = i == active;
                  return Container(
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: states.isHovered && !isActive
                          ? theme.resources.subtleFillColorSecondary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border(
                        bottom: BorderSide(
                          color: isActive ? context.appTheme.colors.selection : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Icon(
                      groups[i].icon,
                      size: 17,
                      color: isActive
                          ? context.appTheme.colors.selection
                          : theme.resources.textFillColorSecondary,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

}

/// One emoji in the grid.
class _EmojiTile extends StatelessWidget {

  final String name;
  final bool isSelected;
  final VoidCallback onPressed;
  final Widget child;

  const _EmojiTile({
    required this.name,
    required this.isSelected,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: HoverButton(
        onPressed: onPressed,
        builder: (context, states) {
          return Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.appTheme.colors.selection.withValues(alpha: 0.16)
                  : states.isHovered
                      ? FluentTheme.of(context).resources.subtleFillColorSecondary
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? context.appTheme.colors.selection : Colors.transparent,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

}

/// Display names and icons for the picker's categories and skin tones. They live
/// here rather than on the enums themselves so the service layer stays free of
/// localization and icon imports.
extension EmojiGroupPresentation on EmojiGroupId {

  IconData get icon => switch (this) {
        EmojiGroupId.smileysEmotion => LucideIcons.smile,
        EmojiGroupId.peopleBody => LucideIcons.user,
        EmojiGroupId.animalsNature => LucideIcons.leaf,
        EmojiGroupId.foodDrink => LucideIcons.utensils,
        EmojiGroupId.travelPlaces => LucideIcons.plane,
        EmojiGroupId.activities => LucideIcons.volleyball,
        EmojiGroupId.objects => LucideIcons.lightbulb,
        EmojiGroupId.symbols => LucideIcons.hash,
        EmojiGroupId.flags => LucideIcons.flag,
      };

  String label(AppLocalizations loc) => switch (this) {
        EmojiGroupId.smileysEmotion => loc.emojiGroup_smileysEmotion,
        EmojiGroupId.peopleBody => loc.emojiGroup_peopleBody,
        EmojiGroupId.animalsNature => loc.emojiGroup_animalsNature,
        EmojiGroupId.foodDrink => loc.emojiGroup_foodDrink,
        EmojiGroupId.travelPlaces => loc.emojiGroup_travelPlaces,
        EmojiGroupId.activities => loc.emojiGroup_activities,
        EmojiGroupId.objects => loc.emojiGroup_objects,
        EmojiGroupId.symbols => loc.emojiGroup_symbols,
        EmojiGroupId.flags => loc.emojiGroup_flags,
      };

}

extension EmojiSkinTonePresentation on EmojiSkinTone {

  String label(AppLocalizations loc) => switch (this) {
        EmojiSkinTone.none => loc.emojiSkinTone_default,
        EmojiSkinTone.light => loc.emojiSkinTone_light,
        EmojiSkinTone.mediumLight => loc.emojiSkinTone_mediumLight,
        EmojiSkinTone.medium => loc.emojiSkinTone_medium,
        EmojiSkinTone.mediumDark => loc.emojiSkinTone_mediumDark,
        EmojiSkinTone.dark => loc.emojiSkinTone_dark,
      };

}
