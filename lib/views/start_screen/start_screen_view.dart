import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/api/board_summary.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/start_screen/start_screen_controller.dart';
import 'package:h3xboard/views/start_screen/start_screen_view_model.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StartScreenView extends ScreenViewBase<StartScreenViewModel, StartScreenController> {

  const StartScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    return ScaffoldPage(
      header: PageHeader(
        title: Text(localizations.startScreen_title),
        commandBar: CommandBar(
          mainAxisAlignment: .end,
          primaryItems: [
            CommandBarButton(
              onPressed: controller.onCreateBoardPressed,
              icon: Icon(LucideIcons.plus),
              label: Text(localizations.startScreen_createBoard),
            ),
            CommandBarButton(
              onPressed: controller.onLogoutPressed,
              icon: Icon(LucideIcons.logOut),
              label: Text(localizations.startScreen_signOut),
            ),
          ],
        ),
      ),
      content: Observer(
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
                    child: Text(localizations.startScreen_retry),
                  ),
                ),
              ),
            );
          }

          if (viewModel.boards.isEmpty) {
            return Center(child: Text(localizations.startScreen_noBoards));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: viewModel.boards.length,
            itemBuilder: (context, index) => _BoardCard(
              board: viewModel.boards[index],
              onOpen: () => controller.openBoard(viewModel.boards[index]),
              onDelete: () => controller.onDeleteBoard(viewModel.boards[index]),
              openLabel: localizations.startScreen_open,
              deleteLabel: localizations.startScreen_delete,
              lastUpdatedLabel: localizations.startScreen_lastUpdated,
            ),
          );
        },
      ),
    );
  }

}

class _BoardCard extends StatelessWidget {

  final BoardSummary board;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final String openLabel;
  final String deleteLabel;
  final String lastUpdatedLabel;

  const _BoardCard({
    required this.board,
    required this.onOpen,
    required this.onDelete,
    required this.openLabel,
    required this.deleteLabel,
    required this.lastUpdatedLabel,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final loc = context.localizations;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text(loc.startScreen_deleteConfirmTitle),
        content: Text(loc.startScreen_deleteConfirmMessage(board.title)),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.startScreen_deleteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(loc.startScreen_deleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final updatedAt = DateFormat.yMMMd().add_Hm().format(board.updatedAt.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(board.title, style: theme.typography.bodyStrong),
                  Text(
                    '$lastUpdatedLabel $updatedAt',
                    style: theme.typography.caption,
                  ),
                ],
              ),
            ),
            Row(
              spacing: 8,
              children: [
                Button(
                  onPressed: onOpen,
                  child: Text(openLabel),
                ),
                Tooltip(
                  message: deleteLabel,
                  child: IconButton(
                    icon: const Icon(LucideIcons.trash2),
                    onPressed: () => _confirmDelete(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
