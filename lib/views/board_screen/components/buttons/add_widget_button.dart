import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/tool_button.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AddWidgetButton extends StatelessWidget {

  final BoardScreenViewModel viewModel;
  final BoardScreenController controller;

  const AddWidgetButton({super.key, required this.viewModel, required this.controller});

  @override
  Widget build(BuildContext context) {
    final localizations = context.localizations;
    return ToolButton(
      icon: LucideIcons.layoutGrid,
      title: localizations.toolToolbar_widgets,
      onPressed: () {},
      flyoutBuilder: (context) => MenuFlyout(
        itemMargin: const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 4),
        items: widgetRegistry.values
            .map(
              (descriptor) => MenuFlyoutItem(
                leading: Icon(descriptor.icon),
                text: Text(descriptor.label(localizations)),
                onPressed: () => controller.onAddWidget(descriptor.defaultConfig),
              ),
            )
            .toList(),
      ),
    );
  }

}
