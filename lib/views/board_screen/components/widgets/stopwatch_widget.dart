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

  // Wall-clock anchor for the running state, carried in the widget's config so the
  // external display reconstructs the exact same elapsed time from the same device
  // clock. [startedAtEpochMs] is null while paused; elapsed = [elapsedMs] + (now -
  // started) while running.
  final int elapsedMs;
  final int? startedAtEpochMs;

  // Emits the new (elapsedMs, startedAtEpochMs) on start/pause/reset. A no-op on
  // the read-only external mirror, so its controls do nothing — but the display
  // still ticks from the anchor.
  final void Function(int elapsedMs, int? startedAtEpochMs) onChanged;

  const StopwatchWidget({
    super.key,
    this.showCentiseconds = true,
    this.elapsedMs = 0,
    this.startedAtEpochMs,
    required this.onChanged,
  });

  @override
  State<StopwatchWidget> createState() => _StopwatchWidgetState();

}

class _StopwatchWidgetState extends State<StopwatchWidget> {

  // Refreshes the display while running; the authoritative state is the config
  // anchor, so this only re-renders — it never holds elapsed time itself.
  Timer? _ticker;

  bool get _isRunning => widget.startedAtEpochMs != null;

  Duration get _elapsed {
    final started = widget.startedAtEpochMs;
    if (started == null) return Duration(milliseconds: widget.elapsedMs);
    final since = DateTime.now().millisecondsSinceEpoch - started;
    return Duration(milliseconds: widget.elapsedMs + (since < 0 ? 0 : since));
  }

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(StopwatchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAtEpochMs != widget.startedAtEpochMs ||
        oldWidget.showCentiseconds != widget.showCentiseconds) {
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (_isRunning) {
      _ticker = Timer.periodic(
        widget.showCentiseconds ? const Duration(milliseconds: 50) : const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    }
  }

  void _toggle() {
    if (_isRunning) {
      // Pause: fold the running span into elapsedMs and drop the anchor.
      widget.onChanged(_elapsed.inMilliseconds, null);
    } else {
      // Start: keep the accumulated elapsed and anchor to the current wall clock.
      widget.onChanged(widget.elapsedMs, DateTime.now().millisecondsSinceEpoch);
    }
  }

  void _reset() => widget.onChanged(0, null);

  @override
  Widget build(BuildContext context) {
    final elapsed = _elapsed;
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
                icon: _isRunning ? LucideIcons.pause : LucideIcons.play,
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
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as StopwatchConfig;
    return StopwatchWidget(
      showCentiseconds: c.showCentiseconds,
      elapsedMs: c.elapsedMs,
      startedAtEpochMs: c.startedAtEpochMs,
      onChanged: (elapsedMs, startedAtEpochMs) =>
          onConfigChanged(c.copyWith(elapsedMs: elapsedMs, startedAtEpochMs: startedAtEpochMs)),
    );
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
