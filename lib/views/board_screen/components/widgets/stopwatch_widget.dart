import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StopwatchWidget extends StatefulWidget {

  static const Size naturalSize = Size(300, 140);

  final bool showCentiseconds;

  const StopwatchWidget({super.key, this.showCentiseconds = true});

  @override
  State<StopwatchWidget> createState() => _StopwatchWidgetState();

}

class _StopwatchWidgetState extends State<StopwatchWidget> {

  final _stopwatch = Stopwatch();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _timer?.cancel();
      _timer = null;
    } else {
      _stopwatch.start();
      _timer = Timer.periodic(
        widget.showCentiseconds ? const Duration(milliseconds: 50) : const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    }
    setState(() {});
  }

  void _reset() {
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
    _stopwatch.reset();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _stopwatch.elapsed;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    final String timeText;
    if (widget.showCentiseconds) {
      final cs = (elapsed.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
      timeText = '$minutes:$seconds.$cs';
    } else {
      timeText = '$minutes:$seconds';
    }

    return Container(
      width: 300,
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xE6111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              timeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w300,
                letterSpacing: 3,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: _stopwatch.isRunning ? LucideIcons.pause : LucideIcons.play,
                onTap: _toggle,
                highlighted: true,
              ),
              const SizedBox(width: 12),
              _ControlButton(
                icon: LucideIcons.rotateCcw,
                onTap: _reset,
                highlighted: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class _ControlButton extends StatelessWidget {

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  const _ControlButton({required this.icon, required this.onTap, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: highlighted ? 0.15 : 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: highlighted ? 0.4 : 0.2),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

}

class StopwatchWidgetDescriptor extends BoardWidgetDescriptor {

  static const StopwatchWidgetDescriptor instance = StopwatchWidgetDescriptor._();
  const StopwatchWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.timer;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_stopwatch;

  @override
  Size naturalSize(BoardWidgetConfig config) => StopwatchWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const StopwatchConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config) {
    final c = config as StopwatchConfig;
    return StopwatchWidget(showCentiseconds: c.showCentiseconds);
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as StopwatchConfig;
    return [
      ToggleMenuFlyoutItem(
        value: c.showCentiseconds,
        text: Text(context.localizations.stopwatchSettingsMenu_showCentiseconds),
        onChanged: (value) => onChange(c.copyWith(showCentiseconds: value)),
      ),
    ];
  }

}
