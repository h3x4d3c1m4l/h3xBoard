import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/widgets/app_menu_flyout.dart';
import 'package:h3xboard/widgets/continuous_menu_flyout.dart';
import 'package:h3xboard/widgets/continuous_text_box.dart';
import 'package:h3xboard/widgets/stable_flyout_controller.dart';
import 'package:h3xboard/widgets/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Continuous (squircle) corner radii for the sub-board tab bar. The tab's inner
// button hugs the outer indicator concentrically (outer − 1), matching the app's
// squircle surfaces instead of fluent's default rounded corners.
const double _subBoardTabRadius = 8;
const double _subBoardButtonRadius = 7;

// Horizontal gap between tabs (and the trailing buttons) — matches the Row's
// `spacing`. The add and overflow buttons are square icon buttons: a 16px icon
// with 6px padding on every side.
const double _tabSpacing = 4;
const double _buttonWidth = 28;

class SubBoardTabBar extends StatefulWidget {

  final List<Board> subBoards;
  final String activeSubBoardId;
  final void Function(String id) onSwitchSubBoard;
  final VoidCallback onAddSubBoard;
  final void Function(String id) onRemoveSubBoard;
  final void Function(String id, String newTitle) onRenameSubBoard;

  const SubBoardTabBar({
    super.key,
    required this.subBoards,
    required this.activeSubBoardId,
    required this.onSwitchSubBoard,
    required this.onAddSubBoard,
    required this.onRemoveSubBoard,
    required this.onRenameSubBoard,
  });

  @override
  State<SubBoardTabBar> createState() => _SubBoardTabBarState();

}

class _SubBoardTabBarState extends State<SubBoardTabBar> {

  // ID of the board currently being renamed inline; null when not editing.
  String? _editingId;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _editFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _editFocus.removeListener(_onFocusChange);
    _editController.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_editFocus.hasFocus && _editingId != null) {
      _commitRename();
    }
  }

  void _startRename(String id, String currentTitle) {
    setState(() {
      _editingId = id;
      _editController.text = currentTitle;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocus.requestFocus();
      _editController.selection = TextSelection(baseOffset: 0, extentOffset: _editController.text.length);
    });
  }

  void _commitRename() {
    final id = _editingId;
    if (id == null) return;
    final newTitle = _editController.text.trim();
    setState(() => _editingId = null);
    if (newTitle.isNotEmpty) {
      widget.onRenameSubBoard(id, newTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Measure against the width handed down by the top bar and, when the tabs
    // don't all fit, collapse the trailing ones behind a "more" button.
    return LayoutBuilder(
      builder: (context, constraints) {
        final (:visible, :overflow) = _split(context, constraints.maxWidth);
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: _tabSpacing,
          children: [
            for (final board in visible)
              _SubBoardTab(
                key: ValueKey(board.id),
                board: board,
                isActive: board.id == widget.activeSubBoardId,
                isEditing: board.id == _editingId,
                editController: _editController,
                editFocus: _editFocus,
                canDelete: widget.subBoards.length > 1,
                onTap: () => widget.onSwitchSubBoard(board.id),
                onSubmitRename: _commitRename,
                onRequestRename: () => _startRename(board.id, board.title),
                onDelete: () => widget.onRemoveSubBoard(board.id),
              ),
            if (overflow.isNotEmpty)
              _OverflowButton(
                boards: overflow,
                onSelect: widget.onSwitchSubBoard,
              ),
            _buildAddButton(context),
            // Rename/delete act on the active board. They mirror the right-click
            // context menu for touch, where a secondary tap isn't available.
            _buildActionButton(
              context,
              icon: LucideIcons.pencil,
              tooltip: context.localizations.subBoardTabBar_rename,
              onPressed: _promptRenameActive,
            ),
            _buildActionButton(
              context,
              icon: LucideIcons.trash2,
              tooltip: context.localizations.subBoardTabBar_delete,
              onPressed: widget.subBoards.length > 1 ? _confirmDeleteActive : null,
            ),
          ],
        );
      },
    );
  }

  /// Splits the boards into the tabs that fit within [maxWidth] and the ones
  /// that overflow. The active board is always kept visible, and the trailing
  /// add button (plus the "more" button when anything overflows) is reserved
  /// for in the budget.
  ({List<Board> visible, List<Board> overflow}) _split(BuildContext context, double maxWidth) {
    final boards = widget.subBoards;
    if (boards.isEmpty || !maxWidth.isFinite) {
      return (visible: boards, overflow: const []);
    }

    final widths = [
      for (final board in boards) _measureTabWidth(context, board, board.id == widget.activeSubBoardId),
    ];

    // Room left once the always-present trailing buttons (add, rename, delete)
    // are reserved for.
    const trailingButtons = 3;
    final tabBudget = maxWidth - trailingButtons * (_buttonWidth + _tabSpacing);

    // Fast path: do all the tabs fit without needing a "more" button?
    var total = 0.0;
    for (var i = 0; i < widths.length; i++) {
      total += widths[i] + (i > 0 ? _tabSpacing : 0);
    }
    if (total <= tabBudget) {
      return (visible: boards, overflow: const []);
    }

    // Otherwise reserve room for the overflow button and greedily fit the
    // leading tabs, always including the active one so it never hides.
    final budget = tabBudget - _buttonWidth - _tabSpacing;
    final activeIndex = boards.indexWhere((b) => b.id == widget.activeSubBoardId);
    final chosen = <int>{if (activeIndex >= 0) activeIndex};
    var used = activeIndex >= 0 ? widths[activeIndex] : 0.0;
    for (var i = 0; i < boards.length; i++) {
      if (chosen.contains(i)) continue;
      final w = widths[i] + (chosen.isEmpty ? 0 : _tabSpacing);
      if (used + w <= budget) {
        used += w;
        chosen.add(i);
      } else {
        break;
      }
    }

    return (
      visible: [for (var i = 0; i < boards.length; i++) if (chosen.contains(i)) boards[i]],
      overflow: [for (var i = 0; i < boards.length; i++) if (!chosen.contains(i)) boards[i]],
    );
  }

  /// Laid-out width of a tab: its label plus the button's horizontal padding.
  /// The active tab renders bold (and so slightly wider), so measure at the
  /// weight it will actually use.
  double _measureTabWidth(BuildContext context, Board board, bool isActive) {
    // A tab being renamed shows a fixed-width edit box (120px field + 8px
    // padding each side) instead of its label.
    if (board.id == _editingId) return 136;

    // Match the tab label's rendered style — the theme font (Lexend) drives the
    // width, so measure with it rather than the platform default.
    final baseStyle = FluentTheme.of(context).typography.body ?? const TextStyle();
    final painter = TextPainter(
      text: TextSpan(
        text: board.title,
        style: baseStyle.copyWith(fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    // 12px padding on each side, plus a small buffer for the border.
    return painter.width + 26;
  }

  Widget _buildAddButton(BuildContext context) {
    return Tooltip(
      message: context.localizations.subBoardTabBar_addBoard,
      child: Button(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsetsDirectional.all(6)),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            ContinuousRectangleBorder(borderRadius: BorderRadius.circular(_subBoardTabRadius)),
          ),
        ),
        onPressed: widget.onAddSubBoard,
        child: const Icon(LucideIcons.plus, size: 16),
      ),
    );
  }

  /// A square trailing icon button matching the add button. [onPressed] may be
  /// null to disable it (e.g. delete when only one board is left).
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Button(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsetsDirectional.all(6)),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            ContinuousRectangleBorder(borderRadius: BorderRadius.circular(_subBoardTabRadius)),
          ),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 16),
      ),
    );
  }

  /// The board the trailing rename/delete buttons act on, or null if the list
  /// is somehow empty.
  Board? get _activeBoard {
    for (final board in widget.subBoards) {
      if (board.id == widget.activeSubBoardId) return board;
    }
    return widget.subBoards.isEmpty ? null : widget.subBoards.first;
  }

  /// Opens a text-input dialog to rename the active board.
  Future<void> _promptRenameActive() async {
    final board = _activeBoard;
    if (board == null) return;
    final loc = context.localizations;
    final textController = TextEditingController(text: board.title);
    // Preselect the current name so the user can immediately overwrite it.
    textController.selection = TextSelection(baseOffset: 0, extentOffset: textController.text.length);
    try {
      final newTitle = await showDialog<String>(
        context: context,
        builder: (ctx) {
          void submit() {
            final value = textController.text.trim();
            if (value.isNotEmpty) Navigator.of(ctx).pop(value);
          }

          return ThemableContentDialog(
            title: Text(loc.subBoardTabBar_renameDialogTitle),
            // The dialog gives its content a Flexible slot; a bare TextBox would
            // stretch to fill it, so hug it to a single line.
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ContinuousTextBox(
                  controller: textController,
                  placeholder: loc.subBoardTabBar_renamePlaceholder,
                  autofocus: true,
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
            actions: [
              Button(onPressed: () => Navigator.of(ctx).pop(), child: Text(loc.subBoardTabBar_renameCancel)),
              FilledButton(onPressed: submit, child: Text(loc.subBoardTabBar_renameConfirm)),
            ],
          );
        },
      );
      if (newTitle != null) widget.onRenameSubBoard(board.id, newTitle);
    } finally {
      textController.dispose();
    }
  }

  /// Opens a warning dialog before deleting the active board.
  Future<void> _confirmDeleteActive() async {
    final board = _activeBoard;
    if (board == null) return;
    final loc = context.localizations;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ThemableContentDialog(
        severity: ThemableDialogSeverity.warning,
        title: Text(loc.subBoardTabBar_deleteConfirmTitle),
        content: Text(loc.subBoardTabBar_deleteConfirmMessage(board.title)),
        actions: [
          Button(onPressed: () => Navigator.of(ctx).pop(false), child: Text(loc.subBoardTabBar_deleteCancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(loc.subBoardTabBar_deleteConfirm)),
        ],
      ),
    );
    if (confirmed == true) widget.onRemoveSubBoard(board.id);
  }

}

/// The "…" button shown when the tabs don't all fit; its flyout lists the
/// overflowing boards and switches to whichever one is tapped.
class _OverflowButton extends StatefulWidget {

  final List<Board> boards;
  final void Function(String id) onSelect;

  const _OverflowButton({required this.boards, required this.onSelect});

  @override
  State<_OverflowButton> createState() => _OverflowButtonState();

}

class _OverflowButtonState extends State<_OverflowButton> {

  final FlyoutController _flyoutController = StableFlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _openMenu() {
    _flyoutController.showFlyout(
      builder: (context) => AppMenuFlyout(
        shape: continuousMenuShape(context),
        itemMargin: kMenuItemMargin,
        items: [
          for (final board in widget.boards)
            MenuFlyoutItem(
              text: Text(board.title),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSelect(board.id);
              },
            ),
        ],
      ),
      placementMode: FlyoutPlacementMode.bottomCenter,
      additionalOffset: 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.localizations.subBoardTabBar_moreBoards,
      child: FlyoutTarget(
        controller: _flyoutController,
        child: Button(
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsetsDirectional.all(6)),
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(
              ContinuousRectangleBorder(borderRadius: BorderRadius.circular(_subBoardTabRadius)),
            ),
          ),
          onPressed: _openMenu,
          child: const Icon(LucideIcons.ellipsis, size: 16),
        ),
      ),
    );
  }

}

class _SubBoardTab extends StatefulWidget {

  final Board board;
  final bool isActive;
  final bool isEditing;
  final TextEditingController editController;
  final FocusNode editFocus;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onSubmitRename;
  final VoidCallback onRequestRename;
  final VoidCallback onDelete;

  const _SubBoardTab({
    super.key,
    required this.board,
    required this.isActive,
    required this.isEditing,
    required this.editController,
    required this.editFocus,
    required this.canDelete,
    required this.onTap,
    required this.onSubmitRename,
    required this.onRequestRename,
    required this.onDelete,
  });

  @override
  State<_SubBoardTab> createState() => _SubBoardTabState();

}

class _SubBoardTabState extends State<_SubBoardTab> {

  final FlyoutController _flyoutController = StableFlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _openContextMenu(BuildContext context) {
    _flyoutController.showFlyout(
      builder: (ctx) => AppMenuFlyout(
        shape: continuousMenuShape(ctx),
        itemMargin: kMenuItemMargin,
        items: [
          MenuFlyoutItem(
            leading: const Icon(LucideIcons.pencil),
            text: Text(context.localizations.subBoardTabBar_rename),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onRequestRename();
            },
          ),
          MenuFlyoutItem(
            leading: Icon(
              LucideIcons.trash2,
              color: widget.canDelete ? const Color(0xFFEF4444) : null,
            ),
            text: Text(context.localizations.subBoardTabBar_delete),
            onPressed: widget.canDelete
                ? () {
                    Navigator.of(ctx).pop();
                    widget.onDelete();
                  }
                : null,
          ),
        ],
      ),
      placementMode: FlyoutPlacementMode.bottomCenter,
      additionalOffset: 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final accentColor = theme.accentColor;

    return GestureDetector(
      onSecondaryTap: () => _openContextMenu(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: ShapeDecoration(
          color: widget.isActive ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(_subBoardTabRadius),
            side: BorderSide(
              color: widget.isActive ? accentColor : theme.resources.controlStrokeColorDefault,
            ),
          ),
        ),
        child: widget.isEditing
            ? SizedBox(
                width: 120,
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ContinuousTextBox(
                    controller: widget.editController,
                    focusNode: widget.editFocus,
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => widget.onSubmitRename(),
                  ),
                ),
              )
            : FlyoutTarget(
                controller: _flyoutController,
                child: Button(
                  style: ButtonStyle(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
                    ),
                    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
                    shape: WidgetStatePropertyAll(
                      ContinuousRectangleBorder(borderRadius: BorderRadius.circular(_subBoardButtonRadius)),
                    ),
                  ),
                  onPressed: widget.onTap,
                  child: Text(
                    widget.board.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

}
