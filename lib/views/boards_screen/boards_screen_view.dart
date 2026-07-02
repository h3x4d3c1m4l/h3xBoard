import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/api/board_summary.dart';
import 'package:h3xboard/models/api/server_info.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/settings_dialog.dart';
import 'package:h3xboard/views/boards_screen/boards_screen_controller.dart';
import 'package:h3xboard/views/boards_screen/boards_screen_view_model.dart';
import 'package:h3xboard/widgets/stable_flyout_controller.dart';
import 'package:h3xboard/widgets/themable_content_dialog.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// The product name shown in the top bar (a proper noun, not localized).
const _appName = 'h3xBoard';

// Card sizing for the responsive board grid.
const double _cardWidth = 300;
const double _cardSpacing = 16;
const double _maxContentWidth = 1240;

class BoardsScreenView extends ScreenViewBase<BoardsScreenViewModel, BoardsScreenController> {

  const BoardsScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopBar(
            onSearchChanged: controller.onSearchChanged,
            onOpenSettings: () => showSettingsDialog(contextAccessor.buildContext),
            onSignOut: controller.onLogoutPressed,
            userDisplayName: controller.userDisplayName,
            userInitials: controller.userInitials,
          ),
          Expanded(
            child: Observer(
              builder: (context) {
                if (viewModel.isLoading) {
                  return const Center(child: ProgressRing());
                }

                if (viewModel.errorMessage != null) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: InfoBar(
                        title: Text(viewModel.errorMessage!),
                        severity: InfoBarSeverity.error,
                        action: Button(
                          onPressed: controller.loadBoards,
                          child: Text(localizations.boardsScreen_retry),
                        ),
                      ),
                    ),
                  );
                }

                return _BoardsBody(
                  boards: viewModel.visibleBoards,
                  totalCount: viewModel.boards.length,
                  reloadToken: viewModel.reloadTick,
                  firstName: controller.firstName,
                  onCreateBoard: controller.onCreateBoardPressed,
                  onOpenBoard: controller.openBoard,
                  onDeleteBoard: controller.onDeleteBoard,
                );
              },
            ),
          ),
          ValueListenableBuilder<ServerInfo?>(
            valueListenable: GetIt.I<ServerController>().serverInfo,
            builder: (context, serverInfo, _) {
              final warning = serverInfo?.warning;
              if (warning == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: InfoBar(
                  title: Text(warning),
                  severity: InfoBarSeverity.warning,
                  isLong: true,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

}

/// The header bar: brand on the left, a live title filter in the middle, and the
/// settings gear + account menu on the right.
class _TopBar extends StatelessWidget {

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenSettings;
  final VoidCallback onSignOut;
  final String userDisplayName;
  final String userInitials;

  const _TopBar({
    required this.onSearchChanged,
    required this.onOpenSettings,
    required this.onSignOut,
    required this.userDisplayName,
    required this.userInitials,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        border: Border(
          bottom: BorderSide(color: theme.resources.controlStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.accentColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.pencil, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(_appName, style: theme.typography.subtitle),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: TextBox(
              placeholder: context.localizations.boardsScreen_searchPlaceholder,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(LucideIcons.search, size: 16),
              ),
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: context.localizations.appSettingsButton_preferences,
            child: IconButton(
              icon: const Icon(LucideIcons.settings, size: 18),
              onPressed: onOpenSettings,
            ),
          ),
          const SizedBox(width: 8),
          _AccountMenu(
            displayName: userDisplayName,
            initials: userInitials,
            onOpenSettings: onOpenSettings,
            onSignOut: onSignOut,
          ),
        ],
      ),
    );
  }

}

/// The account chip in the top-right; tapping it opens a flyout with Preferences
/// and Sign out.
class _AccountMenu extends StatefulWidget {

  final String displayName;
  final String initials;
  final VoidCallback onOpenSettings;
  final VoidCallback onSignOut;

  const _AccountMenu({
    required this.displayName,
    required this.initials,
    required this.onOpenSettings,
    required this.onSignOut,
  });

  @override
  State<_AccountMenu> createState() => _AccountMenuState();

}

class _AccountMenuState extends State<_AccountMenu> {

  final _flyoutController = StableFlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _showMenu() {
    final loc = context.localizations;
    _flyoutController.showFlyout(
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.slidersHorizontal),
            text: Text(loc.appSettingsButton_preferences),
            onPressed: widget.onOpenSettings,
          ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.logOut),
            text: Text(loc.boardsScreen_signOut),
            onPressed: widget.onSignOut,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return FlyoutTarget(
      controller: _flyoutController,
      child: HoverButton(
        onPressed: _showMenu,
        builder: (context, states) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: states.isHovered
                  ? theme.resources.subtleFillColorSecondary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.displayName.isNotEmpty) ...[
                  Text(widget.displayName, style: theme.typography.body),
                  const SizedBox(width: 8),
                ],
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    widget.initials,
                    style: theme.typography.caption?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

/// The scrollable content below the top bar: greeting, board count, the "New
/// board" button, and the responsive grid of board cards.
class _BoardsBody extends StatelessWidget {

  final List<BoardSummary> boards;
  final int totalCount;
  final int reloadToken;
  final String? firstName;
  final VoidCallback onCreateBoard;
  final ValueChanged<BoardSummary> onOpenBoard;
  final ValueChanged<BoardSummary> onDeleteBoard;

  const _BoardsBody({
    required this.boards,
    required this.totalCount,
    required this.reloadToken,
    required this.firstName,
    required this.onCreateBoard,
    required this.onOpenBoard,
    required this.onDeleteBoard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final loc = context.localizations;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(loc, firstName), style: theme.typography.title),
                        const SizedBox(height: 4),
                        Text(
                          loc.boardsScreen_boardCount(totalCount),
                          style: theme.typography.body?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: onCreateBoard,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.plus, size: 16),
                          const SizedBox(width: 8),
                          Text(loc.boardsScreen_createBoard),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                loc.boardsScreen_allBoards.toUpperCase(),
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: _cardSpacing,
                runSpacing: _cardSpacing,
                children: [
                  _NewBoardCard(onPressed: onCreateBoard),
                  for (final board in boards)
                    _BoardCard(
                      board: board,
                      reloadToken: reloadToken,
                      onOpen: () => onOpenBoard(board),
                      onDelete: () => onDeleteBoard(board),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// The dashed "create a fresh board" tile, always shown first in the grid.
class _NewBoardCard extends StatelessWidget {

  final VoidCallback onPressed;

  const _NewBoardCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final loc = context.localizations;
    return SizedBox(
      width: _cardWidth,
      child: HoverButton(
        onPressed: onPressed,
        builder: (context, states) {
          final active = states.isHovered || states.isFocused;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: _cardHeight,
            decoration: BoxDecoration(
              color: active ? theme.accentColor.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? theme.accentColor.withValues(alpha: 0.6) : theme.resources.controlStrokeColorDefault,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.plus, color: theme.accentColor),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.boardsScreen_newBlankBoard,
                  style: theme.typography.bodyStrong?.copyWith(color: theme.accentColor),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

// A card's total height: thumbnail area + footer.
const double _thumbHeight = 176;
const double _cardHeight = _thumbHeight + 68;

/// A single board tile: screenshot thumbnail on top, title + "edited" time and a
/// "…" menu (delete) below. The whole card opens the board.
class _BoardCard extends StatelessWidget {

  final BoardSummary board;
  final int reloadToken;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _BoardCard({
    required this.board,
    required this.reloadToken,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final loc = context.localizations;
    return SizedBox(
      width: _cardWidth,
      child: HoverButton(
        onPressed: onOpen,
        builder: (context, states) {
          final active = states.isHovered || states.isFocused;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: theme.resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? theme.accentColor.withValues(alpha: 0.6) : theme.resources.controlStrokeColorDefault,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _thumbHeight,
                  child: _BoardThumbnail(board: board, reloadToken: reloadToken),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              board.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.bodyStrong,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _editedLabel(loc, board.updatedAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption?.copyWith(
                                color: theme.resources.textFillColorSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CardMenu(title: board.title, onDelete: onDelete),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

/// Loads and shows a board's screenshot, or a neutral placeholder while loading,
/// on failure, or when the board has no screenshot yet.
class _BoardThumbnail extends StatefulWidget {

  final BoardSummary board;

  /// Changes whenever the boards screen reloads; a new value re-fetches the
  /// screenshot (which may have changed with no visible field change).
  final int reloadToken;

  const _BoardThumbnail({required this.board, required this.reloadToken});

  @override
  State<_BoardThumbnail> createState() => _BoardThumbnailState();

}

class _BoardThumbnailState extends State<_BoardThumbnail> {

  final _fileService = GetIt.I<H3xBoardFileService>();
  Uint8List? _bytes;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(_BoardThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch on a reload or if this card was recycled for a different board.
    if (oldWidget.reloadToken != widget.reloadToken || oldWidget.board.id != widget.board.id) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (!widget.board.hasScreenshot) {
      if (_bytes != null && mounted) setState(() => _bytes = null);
      return;
    }
    if (_fetching) return;
    _fetching = true;
    try {
      final bytes = await _fileService.downloadBoardScreenshot(widget.board.id);
      // Keep the previous image on a null/empty result rather than flashing a
      // placeholder over a board that does have a screenshot.
      if (mounted && bytes != null) setState(() => _bytes = bytes);
    } catch (_) {
      // Keep whatever we were already showing.
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      // Show a spinner while we expect an image; a neutral tile otherwise.
      return _ThumbPlaceholder(loading: widget.board.hasScreenshot);
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const _ThumbPlaceholder(),
    );
  }

}

class _ThumbPlaceholder extends StatelessWidget {

  final bool loading;

  const _ThumbPlaceholder({this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ColoredBox(
      color: theme.resources.subtleFillColorSecondary,
      child: Center(
        child: loading
            ? const SizedBox(width: 18, height: 18, child: ProgressRing(strokeWidth: 2))
            : Icon(
                LucideIcons.layoutDashboard,
                size: 28,
                color: theme.resources.textFillColorDisabled,
              ),
      ),
    );
  }

}

/// The per-card "…" overflow menu (currently just Delete, with confirmation).
class _CardMenu extends StatefulWidget {

  final String title;
  final VoidCallback onDelete;

  const _CardMenu({required this.title, required this.onDelete});

  @override
  State<_CardMenu> createState() => _CardMenuState();

}

class _CardMenuState extends State<_CardMenu> {

  final _flyoutController = StableFlyoutController();

  void _showMenu() {
    final loc = context.localizations;
    _flyoutController.showFlyout(
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            leading: Icon(LucideIcons.trash2, color: Colors.red),
            text: Text(loc.boardsScreen_delete, style: TextStyle(color: Colors.red)),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final loc = context.localizations;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ThemableContentDialog(
        severity: ThemableDialogSeverity.error,
        title: Text(loc.boardsScreen_deleteConfirmTitle),
        content: Text(loc.boardsScreen_deleteConfirmMessage(widget.title)),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.boardsScreen_deleteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.boardsScreen_deleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: _flyoutController,
      child: IconButton(
        icon: const Icon(LucideIcons.ellipsis, size: 18),
        onPressed: _showMenu,
      ),
    );
  }

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

}

/// Time-of-day greeting, personalised with [firstName] when we know it.
String _greeting(AppLocalizations loc, String? firstName) {
  final hour = DateTime.now().hour;
  final word = hour < 12
      ? loc.boardsScreen_goodMorning
      : hour < 18
          ? loc.boardsScreen_goodAfternoon
          : loc.boardsScreen_goodEvening;
  if (firstName == null) return word;
  return loc.boardsScreen_greetingNamed(word, firstName);
}

/// A friendly relative "edited …" label, falling back to an absolute date for
/// anything older than a few weeks.
String _editedLabel(AppLocalizations loc, DateTime updatedAt) {
  final diff = DateTime.now().difference(updatedAt.toLocal());
  if (diff.inMinutes < 1) return loc.boardsScreen_editedJustNow;
  if (diff.inMinutes < 60) return loc.boardsScreen_editedMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return loc.boardsScreen_editedHoursAgo(diff.inHours);
  if (diff.inDays == 1) return loc.boardsScreen_editedYesterday;
  if (diff.inDays < 7) return loc.boardsScreen_editedDaysAgo(diff.inDays);
  if (diff.inDays < 28) return loc.boardsScreen_editedWeeksAgo(diff.inDays ~/ 7);
  return loc.boardsScreen_editedOn(DateFormat.yMMMd().format(updatedAt.toLocal()));
}
