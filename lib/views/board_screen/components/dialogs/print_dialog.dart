import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_export.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/export_options_form.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/themable_panel_dialog.dart';

/// Asks which sub-boards to print and at what quality, and resolves to the
/// resulting [ExportRequest] — or `null` when dismissed. There is no format
/// choice: printing always goes through a PDF, one page per sub-board.
Future<ExportRequest?> showPrintDialog(
  BuildContext context, {
  required List<Board> subBoards,
  required String activeSubBoardId,
}) {
  return showDialog<ExportRequest>(
    context: context,
    barrierDismissible: true,
    builder: (_) => PrintDialog(subBoards: subBoards, activeSubBoardId: activeSubBoardId),
  );
}

class PrintDialog extends StatefulWidget {

  final List<Board> subBoards;
  final String activeSubBoardId;

  const PrintDialog({
    super.key,
    required this.subBoards,
    required this.activeSubBoardId,
  });

  @override
  State<PrintDialog> createState() => _PrintDialogState();

}

class _PrintDialogState extends State<PrintDialog> {

  ExportQuality _quality = ExportQuality.normal;
  late final Set<String> _selectedSubBoardIds = {widget.activeSubBoardId};

  void _confirm() {
    Navigator.of(context).pop(ExportRequest(
      format: ExportFormat.pdf,
      quality: _quality,
      subBoardIds: _selectedSubBoardIds.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return ThemablePanelDialog(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
      content: SizedBox(
        width: 560,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExportDialogHeader(
                title: loc.printDialog_title,
                subtitle: loc.printDialog_subtitle,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: ExportOptionsForm(
                    subBoards: widget.subBoards,
                    selectedSubBoardIds: _selectedSubBoardIds,
                    quality: _quality,
                    onQualityChanged: (value) => setState(() => _quality = value),
                    onSubBoardToggled: (id, selected) => setState(() {
                      selected ? _selectedSubBoardIds.add(id) : _selectedSubBoardIds.remove(id);
                    }),
                    onAllSubBoardsToggled: (selected) => setState(() {
                      _selectedSubBoardIds
                        ..clear()
                        ..addAll(selected ? widget.subBoards.map((b) => b.id) : [widget.activeSubBoardId]);
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      rightActions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.printDialog_cancel),
        ),
        FilledButton(
          onPressed: _selectedSubBoardIds.isEmpty ? null : _confirm,
          child: Text(loc.printDialog_print),
        ),
      ],
    );
  }

}
