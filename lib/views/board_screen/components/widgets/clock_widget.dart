import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/tabular_text.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_surface.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DigitalClockWidget extends StatefulWidget {

  /// `hh:mm` and the margin around it — the smallest the card ever gets.
  static const Size _baseSize = Size(220, 100);

  /// What `:ss` adds.
  static const double _secondsWidth = 80;

  /// What the gap and `AM` add, in 12h mode.
  static const double _amPmWidth = 40;

  /// The card follows the readout: seconds add a group, 12h adds a suffix, and
  /// a clock showing neither should not sit in a card sized for both.
  ///
  /// The parts are measured against the app font at the sizes [build] uses, and
  /// leave roughly the same margin in all four combinations. They are a chosen
  /// footprint rather than a derivation — a font whose digits run wider would
  /// leave less margin, and the `FittedBox` in [build] is what keeps that a
  /// matter of looks rather than of clipping.
  static Size sizeFor({required bool use24h, required bool showSeconds}) => Size(
        _baseSize.width + (showSeconds ? _secondsWidth : 0) + (use24h ? 0 : _amPmWidth),
        _baseSize.height,
      );

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

    final size = DigitalClockWidget.sizeFor(use24h: widget.use24h, showSeconds: widget.showSeconds);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: BoardWidgetSurface(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: amPm == null
              ? TabularText(
                  timeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    TabularText(
                      timeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 3,
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
  Size naturalSize(BoardWidgetConfig config) {
    final c = config as DigitalClockConfig;
    return DigitalClockWidget.sizeFor(use24h: c.use24h, showSeconds: c.showSeconds);
  }

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
