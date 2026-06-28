import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/widgets/continuous_text_box.dart';
import 'package:h3xboard/widgets/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class TodoListWidget extends StatelessWidget {

  static const double width = 360;
  static const double _hPad = 22;
  static const double _topPad = 18;
  static const double _bottomPad = 18;
  static const double _titleHeight = 32;
  static const double _titleGap = 12;
  static const double _rowHeight = 42;
  static const double _borderWidth = 1;

  static const Color _checkColor = Color(0xFF4ADE80);

  /// Natural size grows with the number of tasks (min one row, so the empty
  /// placeholder always has room).
  static Size sizeFor(int itemCount) {
    final rows = itemCount < 1 ? 1 : itemCount;
    final height = _topPad + _titleHeight + _titleGap + rows * _rowHeight + _bottomPad + 2 * _borderWidth;
    return Size(width, height);
  }

  final String title;
  final List<TodoItem> items;
  final void Function(int index) onToggle;

  const TodoListWidget({
    super.key,
    required this.title,
    required this.items,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title.trim().isEmpty ? context.localizations.todoList_defaultTitle : title;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xE6111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: _borderWidth),
      ),
      padding: const EdgeInsets.fromLTRB(_hPad, _topPad, _hPad, _bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _titleHeight,
            child: Row(
              mainAxisAlignment: .center,
              children: [
                const Icon(LucideIcons.listChecks, color: _checkColor, size: 22),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    resolvedTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          //const SizedBox(height: _titleGap),
          Divider(size: _titleGap, style: DividerThemeData()),
          if (items.isEmpty)
            const _EmptyPlaceholder()
          else
            for (var i = 0; i < items.length; i++)
              _TodoRow(
                item: items[i],
                onTap: () => onToggle(i),
              ),
        ],
      ),
    );
  }

}

class _TodoRow extends StatelessWidget {

  final TodoItem item;
  final VoidCallback onTap;

  const _TodoRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TodoListWidget._rowHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            _Checkbox(checked: item.done),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: item.done ? Colors.white.withValues(alpha: 0.45) : Colors.white,
                  fontSize: 18,
                  decoration: item.done ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _Checkbox extends StatelessWidget {

  final bool checked;

  const _Checkbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? TodoListWidget._checkColor : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: checked ? TodoListWidget._checkColor : Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: checked ? const Icon(LucideIcons.check, color: Color(0xFF0B1220), size: 16) : null,
    );
  }

}

class _EmptyPlaceholder extends StatelessWidget {

  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TodoListWidget._rowHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          context.localizations.todoList_empty,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 18,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

}

class TodoListWidgetDescriptor extends BoardWidgetDescriptor {

  static const TodoListWidgetDescriptor instance = TodoListWidgetDescriptor._();
  const TodoListWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.listTodo;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_todoList;

  @override
  Size naturalSize(BoardWidgetConfig config) => TodoListWidget.sizeFor((config as TodoListConfig).items.length);

  @override
  BoardWidgetConfig get defaultConfig => const TodoListConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as TodoListConfig;
    return TodoListWidget(
      title: c.title,
      items: c.items,
      onToggle: (index) {
        final updated = [...c.items];
        updated[index] = updated[index].copyWith(done: !updated[index].done);
        onConfigChanged(c.copyWith(items: updated));
      },
    );
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as TodoListConfig;
    final loc = context.localizations;

    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.pencil, size: 16),
        text: Text(loc.todoListSettingsMenu_editItems),
        onPressed: () => _showEditDialog(context, c, onChange),
      ),
    ];
  }

  static void _showEditDialog(
    BuildContext context,
    TodoListConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final loc = context.localizations;
    final titleController = TextEditingController(text: config.title);
    final itemsController = TextEditingController(text: config.items.map((i) => i.text).join('\n'));

    showDialog<void>(
      context: context,
      builder: (ctx) => ThemableContentDialog(
        title: Text(loc.todoListSettingsMenu_editDialogTitle),
        constraints: const BoxConstraints(maxWidth: 520),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ContinuousTextBox(
              controller: titleController,
              placeholder: loc.todoListSettingsMenu_titlePlaceholder,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ContinuousTextBox(
              controller: itemsController,
              maxLines: null,
              minLines: 8,
              placeholder: loc.todoListSettingsMenu_itemsPlaceholder,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.todoListSettingsMenu_cancel),
          ),
          FilledButton(
            onPressed: () {
              onChange(config.copyWith(
                title: titleController.text.trim(),
                items: _parseItems(itemsController.text, config.items),
              ));
              Navigator.of(ctx).pop();
            },
            child: Text(loc.todoListSettingsMenu_save),
          ),
        ],
      ),
    );
  }

  /// Turns the edit box (one task per line) into [TodoItem]s, preserving the
  /// done-state of any task whose text is unchanged.
  static List<TodoItem> _parseItems(String raw, List<TodoItem> existing) {
    final doneByText = <String, bool>{};
    for (final item in existing) {
      doneByText.putIfAbsent(item.text, () => item.done);
    }

    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => TodoItem(text: line, done: doneByText[line] ?? false))
        .toList();
  }

}
