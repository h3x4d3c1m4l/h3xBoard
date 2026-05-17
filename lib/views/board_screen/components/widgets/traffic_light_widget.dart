import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';

class TrafficLightWidget extends StatelessWidget {

  static const Size naturalSize = Size(100, 260);

  final TrafficLightColor activeLight;

  const TrafficLightWidget({super.key, this.activeLight = TrafficLightColor.red});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Light(color: TrafficLightColor.red, activeLight: activeLight),
          _Light(color: TrafficLightColor.yellow, activeLight: activeLight),
          _Light(color: TrafficLightColor.green, activeLight: activeLight),
        ],
      ),
    );
  }

}

class _Light extends StatelessWidget {

  final TrafficLightColor color;
  final TrafficLightColor activeLight;

  const _Light({required this.color, required this.activeLight});

  @override
  Widget build(BuildContext context) {
    final isActive = color == activeLight;
    final (activeColor, inactiveColor) = switch (color) {
      TrafficLightColor.red => (const Color(0xFFFF3B30), const Color(0xFF3A0A08)),
      TrafficLightColor.yellow => (const Color(0xFFFFCC00), const Color(0xFF2A2000)),
      TrafficLightColor.green => (const Color(0xFF34C759), const Color(0xFF0A2418)),
    };

    final displayColor = isActive ? activeColor : inactiveColor;

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: displayColor,
        boxShadow: isActive
            ? [BoxShadow(color: activeColor.withValues(alpha: 0.7), blurRadius: 16, spreadRadius: 2)]
            : null,
      ),
    );
  }

}

class TrafficLightWidgetDescriptor extends BoardWidgetDescriptor {

  static const TrafficLightWidgetDescriptor instance = TrafficLightWidgetDescriptor._();
  const TrafficLightWidgetDescriptor._();

  @override
  Size get naturalSize => TrafficLightWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const TrafficLightConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config) {
    final c = config as TrafficLightConfig;
    return TrafficLightWidget(activeLight: c.activeLight);
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as TrafficLightConfig;

    RadioMenuFlyoutItem<TrafficLightColor> lightItem(TrafficLightColor color, Color dot, String label) {
      return RadioMenuFlyoutItem<TrafficLightColor>(
        value: color,
        groupValue: c.activeLight,
        text: Text(label),
        trailing: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
        ),
        onChanged: (color) => onChange(c.copyWith(activeLight: color)),
      );
    }

    return [
      lightItem(TrafficLightColor.red, const Color(0xFFFF3B30), context.localizations.trafficLightSettingsMenu_red),
      lightItem(TrafficLightColor.yellow, const Color(0xFFFFCC00), context.localizations.trafficLightSettingsMenu_yellow),
      lightItem(TrafficLightColor.green, const Color(0xFF34C759), context.localizations.trafficLightSettingsMenu_green),
    ];
  }

}
