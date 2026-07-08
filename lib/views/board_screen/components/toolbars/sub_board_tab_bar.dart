import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/widgets/continuous_menu_flyout.dart';
import 'package:h3xboard/widgets/continuous_text_box.dart';
import 'package:h3xboard/widgets/stable_flyout_controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Continuous (squircle) corner radii for the sub-board tab bar. The tab's inner
// button hugs the outer indicator concentrically (outer − 1), matching the app's
// squircle surfaces instead of fluent's default rounded corners.
const double _subBoardTabRadius = 8;
const double _subBoardButtonRadius = 7;

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        for (final board in widget.subBoards)
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
        _buildAddButton(context),
      ],
    );
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
      builder: (ctx) => MenuFlyout(
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
