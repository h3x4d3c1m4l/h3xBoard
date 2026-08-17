import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_surface.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Stands in for a widget a live-share mirror was sent but can't draw, because
/// the presenter runs a newer version of the app. Built only from
/// [UnsupportedConfig], which only the live-share decode path mints — a board
/// being edited never contains one.
///
/// Wears the family card: it occupies a widget's slot, so it should read as one
/// that has something to say rather than as damage.
class UnsupportedWidget extends StatelessWidget {

  // The real widget's size lives in a build that isn't here, so the card takes a
  // neutral one. Placement is still right — x/y are the widget's centre.
  static const Size naturalSize = Size(360, 240);

  const UnsupportedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations;
    return SizedBox(
      width: naturalSize.width,
      height: naturalSize.height,
      child: BoardWidgetSurface(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            const Icon(LucideIcons.triangleAlert, size: 40, color: Colors.white),
            Text(
              localizations.unsupportedWidget_title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              localizations.unsupportedWidget_message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

}

class UnsupportedWidgetDescriptor extends BoardWidgetDescriptor {

  static const UnsupportedWidgetDescriptor instance = UnsupportedWidgetDescriptor._();
  const UnsupportedWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.triangleAlert;

  @override
  String label(AppLocalizations localizations) => localizations.unsupportedWidget_title;

  @override
  Size naturalSize(BoardWidgetConfig config) => UnsupportedWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const UnsupportedConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) =>
      const UnsupportedWidget();

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) =>
      const [];

  // Not something anyone can add: it only ever arrives over the wire.
  @override
  bool get showInCatalog => false;

}
