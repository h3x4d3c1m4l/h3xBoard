import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class QrCodeWidget extends StatelessWidget {

  static const Size naturalSize = Size(300, 300);

  // Stand-in payload rendered (faded, with a hint on top) while the widget has no
  // data yet, so an empty QR widget still reads as a QR code on the board.
  static const _previewData = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

  final String data;
  final QrCodeStyle style;

  const QrCodeWidget({super.key, this.data = '', this.style = QrCodeStyle.smooth});

  static PrettyQrShape _shapeFor(QrCodeStyle style) => switch (style) {
        QrCodeStyle.smooth => const PrettyQrSmoothSymbol(color: Color(0xFF1A1A1A)),
        QrCodeStyle.square => const PrettyQrSquaresSymbol(color: Color(0xFF1A1A1A)),
        QrCodeStyle.dots => const PrettyQrDotsSymbol(color: Color(0xFF1A1A1A)),
      };

  @override
  Widget build(BuildContext context) {
    final isEmpty = data.isEmpty;

    // A white plate with a quiet zone keeps the code scannable whatever the board
    // background or drawing underneath it happens to be.
    return SizedBox(
      width: naturalSize.width,
      height: naturalSize.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: isEmpty ? 0.15 : 1,
                child: PrettyQrView.data(
                  data: isEmpty ? _previewData : data,
                  errorCorrectLevel: QrErrorCorrectLevel.M,
                  decoration: PrettyQrDecoration(shape: _shapeFor(style)),
                ),
              ),
              if (isEmpty)
                Text(
                  context.localizations.qrCode_noData,
                  style: const TextStyle(color: Color(0xFF808080), fontSize: 16, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
      ),
    );
  }

}

class QrCodeWidgetDescriptor extends BoardWidgetDescriptor {

  static const QrCodeWidgetDescriptor instance = QrCodeWidgetDescriptor._();
  const QrCodeWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.qrCode;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_qrCode;

  @override
  Size naturalSize(BoardWidgetConfig config) => QrCodeWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const QrCodeConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as QrCodeConfig;
    return QrCodeWidget(data: c.data, style: c.style);
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as QrCodeConfig;
    final loc = context.localizations;

    RadioMenuFlyoutItem<QrCodeStyle> styleItem(QrCodeStyle style, String label) {
      return RadioMenuFlyoutItem<QrCodeStyle>(
        value: style,
        groupValue: c.style,
        text: Text(label),
        onChanged: (value) => onChange(c.copyWith(style: value)),
      );
    }

    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.pencil, size: 16),
        text: Text(loc.qrCodeSettingsMenu_editData),
        onPressed: () => _showEditDialog(context, c, onChange),
      ),
      const MenuFlyoutSeparator(),
      styleItem(QrCodeStyle.smooth, loc.qrCodeSettingsMenu_styleSmooth),
      styleItem(QrCodeStyle.square, loc.qrCodeSettingsMenu_styleSquare),
      styleItem(QrCodeStyle.dots, loc.qrCodeSettingsMenu_styleDots),
    ];
  }

  @override
  VoidCallback? editAction(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) =>
      () => _showEditDialog(context, config as QrCodeConfig, onChange);

  static void _showEditDialog(
    BuildContext context,
    QrCodeConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final loc = context.localizations;
    final controller = TextEditingController(text: config.data);

    showDialog<void>(
      context: context,
      builder: (ctx) => ThemableContentDialog(
        title: Text(loc.qrCodeSettingsMenu_editDataDialogTitle),
        constraints: const BoxConstraints(maxWidth: 520),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ContinuousTextBox(
              controller: controller,
              autofocus: true,
              maxLines: null,
              minLines: 3,
              placeholder: loc.qrCodeSettingsMenu_editDataPlaceholder,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.qrCodeSettingsMenu_cancel),
          ),
          FilledButton(
            onPressed: () {
              onChange(config.copyWith(data: controller.text.trim()));
              Navigator.of(ctx).pop();
            },
            child: Text(loc.qrCodeSettingsMenu_save),
          ),
        ],
      ),
    );
  }

}
