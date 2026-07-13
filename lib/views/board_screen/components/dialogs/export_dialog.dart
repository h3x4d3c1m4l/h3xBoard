import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_export.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/export_options_form.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/themable_panel_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Asks what to export and how, and resolves to the resulting [ExportRequest] —
/// or `null` when dismissed. [activeSubBoardId] is pre-selected, so the common
/// case (export what I'm looking at) is one click away.
Future<ExportRequest?> showExportDialog(
  BuildContext context, {
  required List<Board> subBoards,
  required String activeSubBoardId,
}) {
  return showDialog<ExportRequest>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ExportDialog(subBoards: subBoards, activeSubBoardId: activeSubBoardId),
  );
}

class ExportDialog extends StatefulWidget {

  final List<Board> subBoards;
  final String activeSubBoardId;

  const ExportDialog({
    super.key,
    required this.subBoards,
    required this.activeSubBoardId,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();

}

class _ExportDialogState extends State<ExportDialog> {

  ExportFormat _format = ExportFormat.pdf;
  ExportQuality _quality = ExportQuality.normal;
  late final Set<String> _selectedSubBoardIds = {widget.activeSubBoardId};

  void _confirm() {
    Navigator.of(context).pop(ExportRequest(
      format: _format,
      quality: _quality,
      subBoardIds: _selectedSubBoardIds.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    // A PDF holds every sub-board; PNG/JPEG produce one file per sub-board.
    final subtitle = _format == ExportFormat.pdf
        ? loc.exportDialog_pdfSubtitle
        : loc.exportDialog_imageSubtitle(_selectedSubBoardIds.length);

    return ThemablePanelDialog(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
      content: SizedBox(
        width: 560,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExportDialogHeader(
                title: loc.exportDialog_title,
                subtitle: subtitle,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExportSection(
                        icon: LucideIcons.fileDown,
                        title: loc.exportDialog_format,
                        child: Row(
                          children: [
                            for (final value in ExportFormat.values) ...[
                              if (value != ExportFormat.values.first) const SizedBox(width: 12),
                              Expanded(
                                child: ExportOptionTile(
                                  icon: switch (value) {
                                    ExportFormat.pdf => LucideIcons.fileText,
                                    ExportFormat.png => LucideIcons.image,
                                    ExportFormat.jpeg => LucideIcons.images,
                                  },
                                  label: switch (value) {
                                    ExportFormat.pdf => loc.exportDialog_formatPdf,
                                    ExportFormat.png => loc.exportDialog_formatPng,
                                    ExportFormat.jpeg => loc.exportDialog_formatJpeg,
                                  },
                                  isActive: _format == value,
                                  onPressed: () => setState(() => _format = value),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ExportOptionsForm(
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
                    ],
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
          child: Text(loc.exportDialog_cancel),
        ),
        FilledButton(
          // Nothing selected = nothing to export.
          onPressed: _selectedSubBoardIds.isEmpty ? null : _confirm,
          child: Text(loc.exportDialog_export),
        ),
      ],
    );
  }

}
