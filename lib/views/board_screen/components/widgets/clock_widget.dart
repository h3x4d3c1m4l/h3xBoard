import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DigitalClockWidget extends StatefulWidget {

  static const Size naturalSize = Size(300, 100);

  final bool use24h;
  final bool showSeconds;

  const DigitalClockWidget({super.key, this.use24h = true, this.showSeconds = true});

  @override
  State<DigitalClockWidget> createState() => _DigitalClockWidgetState();

}

class _DigitalClockWidgetState extends State<DigitalClockWidget> {

  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');

    final String timeText;
    final String? amPm;

    if (widget.use24h) {
      final h = _now.hour.toString().padLeft(2, '0');
      timeText = widget.showSeconds ? '$h:$m:$s' : '$h:$m';
      amPm = null;
    } else {
      final hour12 = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
      final h = hour12.toString().padLeft(2, '0');
      timeText = widget.showSeconds ? '$h:$m:$s' : '$h:$m';
      amPm = _now.hour < 12 ? 'AM' : 'PM';
    }

    return Container(
      width: 300,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xE6111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 1),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: amPm == null
            ? Text(
                timeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    timeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 3,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    amPm,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

}

class DigitalClockWidgetDescriptor extends BoardWidgetDescriptor {

  static const DigitalClockWidgetDescriptor instance = DigitalClockWidgetDescriptor._();
  const DigitalClockWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.clock;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_digitalClock;

  @override
  Size naturalSize(BoardWidgetConfig config) => DigitalClockWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const DigitalClockConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as DigitalClockConfig;
    return DigitalClockWidget(use24h: c.use24h, showSeconds: c.showSeconds);
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as DigitalClockConfig;
    return [
      ToggleMenuFlyoutItem(
        value: c.use24h,
        text: Text(context.localizations.clockSettingsMenu_24h),
        onChanged: (value) => onChange(c.copyWith(use24h: value)),
      ),
      ToggleMenuFlyoutItem(
        value: c.showSeconds,
        text: Text(context.localizations.clockSettingsMenu_showSeconds),
        onChanged: (value) => onChange(c.copyWith(showSeconds: value)),
      ),
    ];
  }

}
