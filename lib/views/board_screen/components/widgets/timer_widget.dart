import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/widgets/continuous_text_box.dart';
import 'package:h3xboard/widgets/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class TimerWidget extends StatefulWidget {

  static const Size naturalSize = Size(300, 140);

  final int durationSeconds;
  final bool showCentiseconds;

  // Wall-clock anchor for the running state, carried in the widget's config so the
  // external display reconstructs the exact same remaining time from the same
  // device clock. [startedAtEpochMs] is null while paused.
  final int elapsedMs;
  final int? startedAtEpochMs;

  // Emits the new (elapsedMs, startedAtEpochMs) on start/pause/reset/finish. A
  // no-op on the read-only external mirror.
  final void Function(int elapsedMs, int? startedAtEpochMs) onChanged;

  const TimerWidget({
    super.key,
    this.durationSeconds = 300,
    this.showCentiseconds = false,
    this.elapsedMs = 0,
    this.startedAtEpochMs,
    required this.onChanged,
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();

}

class _TimerWidgetState extends State<TimerWidget> with SingleTickerProviderStateMixin {

  // Refreshes the display while counting down; the authoritative state is the
  // config anchor, so this only re-renders — it never holds elapsed time itself.
  Timer? _ticker;

  // Drives the finished-state border flicker: a smooth fade in/out that repeats
  // (reversing) while the countdown sits at zero, and is held still otherwise.
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  Duration get _total => Duration(seconds: widget.durationSeconds);

  bool get _isRunning => widget.startedAtEpochMs != null;

  Duration get _elapsed {
    final started = widget.startedAtEpochMs;
    if (started == null) return Duration(milliseconds: widget.elapsedMs);
    final since = DateTime.now().millisecondsSinceEpoch - started;
    return Duration(milliseconds: widget.elapsedMs + (since < 0 ? 0 : since));
  }

  Duration get _remaining {
    final r = _total - _elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  bool get _finished => _remaining == Duration.zero && _elapsed > Duration.zero;

  @override
  void initState() {
    super.initState();
    _syncState();
  }

  @override
  void didUpdateWidget(TimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAtEpochMs != widget.startedAtEpochMs ||
        oldWidget.elapsedMs != widget.elapsedMs ||
        oldWidget.durationSeconds != widget.durationSeconds ||
        oldWidget.showCentiseconds != widget.showCentiseconds) {
      _syncState();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _flicker.dispose();
    super.dispose();
  }

  // Runs the display ticker while counting down and the fade-flicker while
  // finished; both are derived from the config anchor.
  void _syncState() {
    _ticker?.cancel();
    _ticker = null;
    if (_isRunning && _remaining > Duration.zero) {
      _ticker = Timer.periodic(
        widget.showCentiseconds ? const Duration(milliseconds: 50) : const Duration(seconds: 1),
        _onTick,
      );
    }
    _syncFlicker();
  }

  // Runs the fade-flicker only while finished; holds the border steady otherwise.
  void _syncFlicker() {
    if (_finished) {
      if (!_flicker.isAnimating) _flicker.repeat(reverse: true);
    } else {
      _flicker
        ..stop()
        ..value = 0;
    }
  }

  void _onTick(Timer _) {
    if (_remaining == Duration.zero) {
      _ticker?.cancel();
      _ticker = null;
      // Settle to a stopped, fully-elapsed state (the editor persists it; a no-op
      // on the mirror, which reaches zero on its own from the same anchor).
      if (_isRunning) widget.onChanged(_total.inMilliseconds, null);
      _syncFlicker();
    }
    setState(() {});
  }

  void _toggle() {
    if (_isRunning) {
      widget.onChanged(_elapsed.inMilliseconds, null);
    } else {
      if (_remaining == Duration.zero) return; // already finished — nothing to count down
      widget.onChanged(widget.elapsedMs, DateTime.now().millisecondsSinceEpoch);
    }
  }

  void _reset() => widget.onChanged(0, null);

  @override
  Widget build(BuildContext context) {
    final d = _remaining;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');

    final String timeText;
    if (hours > 0) {
      timeText = '${two(hours)}:${two(minutes)}:${two(seconds)}';
    } else if (widget.showCentiseconds) {
      final cs = d.inMilliseconds.remainder(1000) ~/ 10;
      timeText = '${two(minutes)}:${two(seconds)}.${two(cs)}';
    } else {
      timeText = '${two(minutes)}:${two(seconds)}';
    }

    final finished = _finished;

    // The flicker fades the red border between near-invisible and full while the
    // timer is finished; eased so the pulse breathes rather than blinks. The inner
    // content is passed as the AnimatedBuilder child so only the border repaints.
    return AnimatedBuilder(
      animation: _flicker,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_flicker.value);
        final borderColor = finished
            ? const Color(0xFFF87171).withValues(alpha: 0.15 + 0.75 * t)
            : Colors.white.withValues(alpha: 0.24);
        return Container(
          width: 300,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xE6111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              timeText,
              style: TextStyle(
                color: finished ? const Color(0xFFF87171) : Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w300,
                letterSpacing: 3,
                fontFeatures: const [FontFeature.tabularFigures()],
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

class TimerWidgetDescriptor extends BoardWidgetDescriptor {

  static const TimerWidgetDescriptor instance = TimerWidgetDescriptor._();
  const TimerWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.hourglass;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_timer;

  @override
  Size naturalSize(BoardWidgetConfig config) => TimerWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const TimerConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as TimerConfig;
    return TimerWidget(
      // Rebuild the internal countdown state when the configured duration changes.
      key: ValueKey('timer_${c.durationSeconds}'),
      durationSeconds: c.durationSeconds,
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
    final c = config as TimerConfig;
    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.pencil, size: 16),
        text: Text(context.localizations.timerSettingsMenu_setDuration),
        onPressed: () => _showDurationDialog(context, c, onChange),
      ),
      ToggleMenuFlyoutItem(
        value: c.showCentiseconds,
        text: Text(context.localizations.stopwatchSettingsMenu_showCentiseconds),
        onChanged: (value) => onChange(c.copyWith(showCentiseconds: value)),
      ),
    ];
  }

  @override
  VoidCallback? editAction(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) =>
      () => _showDurationDialog(context, config as TimerConfig, onChange);

  static void _showDurationDialog(
    BuildContext context,
    TimerConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final loc = context.localizations;
    final minutesController = TextEditingController(text: (config.durationSeconds ~/ 60).toString());
    final secondsController = TextEditingController(text: (config.durationSeconds % 60).toString());

    int parse(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

    showDialog<void>(
      context: context,
      builder: (ctx) => ThemableContentDialog(
        title: Text(loc.timerSettingsMenu_setDurationDialogTitle),
        constraints: const BoxConstraints(maxWidth: 360),
        content: Row(
          children: [
            Expanded(
              child: _DurationField(
                controller: minutesController,
                label: loc.timerSettingsMenu_minutes,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DurationField(
                controller: secondsController,
                label: loc.timerSettingsMenu_seconds,
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.timerSettingsMenu_cancel),
          ),
          FilledButton(
            onPressed: () {
              final total = parse(minutesController) * 60 + parse(secondsController);
              // Changing the duration resets any running countdown to the new time.
              onChange(config.copyWith(
                durationSeconds: total.clamp(1, 24 * 3600),
                elapsedMs: 0,
                startedAtEpochMs: null,
              ));
              Navigator.of(ctx).pop();
            },
            child: Text(loc.timerSettingsMenu_save),
          ),
        ],
      ),
    );
  }

}

class _DurationField extends StatelessWidget {

  final TextEditingController controller;
  final String label;

  const _DurationField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FluentTheme.of(context).typography.caption),
        const SizedBox(height: 4),
        ContinuousTextBox(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

}
