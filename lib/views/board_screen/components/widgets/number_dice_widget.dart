import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/tabular_text.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/dice_roll.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

final math.Random _random = math.Random();

// Wide enough to be worth rolling, narrow enough that the tile stays legible on
// a board; also keeps the arithmetic in [numberDiceValueAt] far from any limit.
const int kNumberDiceLimit = 99999;

/// The config a roll produces. Like [DiceConfig], the value is drawn on the
/// presenter and the mirrors only reproduce the flicker leading up to it.
NumberDiceConfig rollNumberDice(NumberDiceConfig config, {math.Random? random, int? nowMs}) => config.copyWith(
      value: drawValue(random ?? _random, config.min, config.max),
      rollSeed: nextRollSeed(config.rollSeed),
      rolledAtEpochMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );

const Color _faceColor = Color(0xFFF8FAFC);
const Color _numberColor = Color(0xFF1E293B);

class NumberDiceWidget extends StatefulWidget {

  static const Size naturalSize = Size(200, 200);

  final int min;
  final int max;
  final int value;
  final int rollSeed;
  final int? rolledAtEpochMs;
  // Null disables rolling, which is what the read-only mirror passes.
  final VoidCallback? onRoll;

  const NumberDiceWidget({
    super.key,
    this.min = 1,
    this.max = 6,
    this.value = 1,
    this.rollSeed = 0,
    this.rolledAtEpochMs,
    this.onRoll,
  });

  @override
  State<NumberDiceWidget> createState() => _NumberDiceWidgetState();

}

class _NumberDiceWidgetState extends State<NumberDiceWidget> with SingleTickerProviderStateMixin {

  // Same design as the 3D die: the anchor in the config is the state, and this is
  // only a frame pump. See dice_widget.dart for why it isn't an AnimationController.
  late final Ticker _ticker = createTicker(_onFrame);

  late final ValueNotifier<int> _elapsed = ValueNotifier(_read());

  int _read() => diceElapsedMs(widget.rolledAtEpochMs, DateTime.now().millisecondsSinceEpoch);

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(NumberDiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rolledAtEpochMs != widget.rolledAtEpochMs) _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  void _syncTicker() {
    final elapsed = _read();
    _elapsed.value = elapsed;
    final rolling = elapsed < kDiceRollDurationMs;
    if (rolling && !_ticker.isActive) {
      _ticker.start();
    } else if (!rolling && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onFrame(Duration _) {
    final elapsed = _read();
    _elapsed.value = elapsed;
    if (elapsed >= kDiceRollDurationMs) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    final tile = RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: _elapsed,
        builder: (context, elapsed, _) {
          final pose = numberDicePoseAt(elapsed);
          final side = NumberDiceWidget.naturalSize.width * pose.scale;
          final shown = numberDiceValueAt(widget.min, widget.max, widget.value, widget.rollSeed, elapsed);

          return Center(
            child: Transform.rotate(
              angle: pose.tilt,
              child: SizedBox.square(
                dimension: side,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _faceColor,
                    borderRadius: BorderRadius.circular(side * 0.18),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(side * 0.16),
                    child: FittedBox(
                      child: TabularText(
                        '$shown',
                        style: const TextStyle(
                          color: _numberColor,
                          fontSize: 96,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    final sized = SizedBox(
      width: NumberDiceWidget.naturalSize.width,
      height: NumberDiceWidget.naturalSize.height,
      child: tile,
    );

    if (widget.onRoll == null) return sized;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onRoll,
        child: sized,
      ),
    );
  }

}

class NumberDiceWidgetDescriptor extends BoardWidgetDescriptor {

  static const NumberDiceWidgetDescriptor instance = NumberDiceWidgetDescriptor._();
  const NumberDiceWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.hash;

  @override
  String get emoji => '🔢';

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_numberDice;

  @override
  Size naturalSize(BoardWidgetConfig config) => NumberDiceWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const NumberDiceConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as NumberDiceConfig;
    return NumberDiceWidget(
      min: c.min,
      max: c.max,
      value: c.value,
      rollSeed: c.rollSeed,
      rolledAtEpochMs: c.rolledAtEpochMs,
      onRoll: () => onConfigChanged(rollNumberDice(c)),
    );
  }

  // No editAction, for the same reason as the 3D die: it would put a double-tap
  // recognizer over the body and stall every roll by the arena's ~300ms hold.

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as NumberDiceConfig;
    final loc = context.localizations;

    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.dices, size: 16),
        text: Text(loc.numberDiceSettingsMenu_roll),
        onPressed: () => onChange(rollNumberDice(c)),
      ),
      const MenuFlyoutSeparator(),
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.pencil, size: 16),
        text: Text(loc.numberDiceSettingsMenu_setRange),
        onPressed: () => _showRangeDialog(context, c, onChange),
      ),
    ];
  }

  static void _showRangeDialog(
    BuildContext context,
    NumberDiceConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final loc = context.localizations;
    final minController = TextEditingController(text: config.min.toString());
    final maxController = TextEditingController(text: config.max.toString());

    int parse(TextEditingController controller, int fallback) =>
        int.tryParse(controller.text.trim()) ?? fallback;

    // Owned by the dialog, not by a State, so they are disposed when the
    // route completes rather than in a dispose() override.
    unawaited(
      showAppDialog<void>(
        context: context,
        builder: (ctx) => ThemableContentDialog(
          title: Text(loc.numberDiceSettingsMenu_setRangeDialogTitle),
          constraints: const BoxConstraints(maxWidth: 360),
          content: Row(
            children: [
              Expanded(child: _RangeField(controller: minController, label: loc.numberDiceSettingsMenu_min)),
              const SizedBox(width: 12),
              Expanded(child: _RangeField(controller: maxController, label: loc.numberDiceSettingsMenu_max)),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.numberDiceSettingsMenu_cancel),
            ),
            FilledButton(
              onPressed: () {
                // A text box hands back whatever was typed, so the invariant is
                // established here rather than assumed downstream: bounds ordered,
                // clamped, and the showing value pulled inside the new range.
                final a = parse(minController, config.min).clamp(-kNumberDiceLimit, kNumberDiceLimit);
                final b = parse(maxController, config.max).clamp(-kNumberDiceLimit, kNumberDiceLimit);
                final min = math.min(a, b);
                final max = math.max(a, b);
                onChange(config.copyWith(
                  min: min,
                  max: max,
                  value: config.value.clamp(min, max),
                  // Changing the range is an edit, not a roll: drop any roll still
                  // in the air rather than letting it land on a stale value.
                  rolledAtEpochMs: null,
                ));
                Navigator.of(ctx).pop();
              },
              child: Text(loc.numberDiceSettingsMenu_save),
            ),
          ],
        ),
      ).whenComplete(() {
        minController.dispose();
        maxController.dispose();
      }),
    );
  }

}

class _RangeField extends StatelessWidget {

  final TextEditingController controller;
  final String label;

  const _RangeField({required this.controller, required this.label});

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
