import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/analog_clock_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/clock_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/memo_note_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/stopwatch_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/traffic_light_widget.dart';

// Abstract descriptor for a board widget type. Each widget file provides a
// concrete singleton implementation that encapsulates construction, natural
// size, and settings menu items. board.dart and manipulable_board_widget.dart
// dispatch through descriptorFor() and never contain type-specific switches.
abstract class BoardWidgetDescriptor {

  const BoardWidgetDescriptor();

  IconData get icon;
  String label(AppLocalizations localizations);
  Size get naturalSize;
  BoardWidgetConfig get defaultConfig;
  Widget buildWidget(BoardWidgetConfig config);
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  );

}

// The single place that maps config types to their descriptors.
// To add a new widget type: add an entry here and nowhere else.
const Map<Type, BoardWidgetDescriptor> _registry = {
  DigitalClockConfig: DigitalClockWidgetDescriptor.instance,
  AnalogClockConfig: AnalogClockWidgetDescriptor.instance,
  TrafficLightConfig: TrafficLightWidgetDescriptor.instance,
  StopwatchConfig: StopwatchWidgetDescriptor.instance,
  MemoNoteConfig: MemoNoteWidgetDescriptor.instance,
};

// All registered descriptors, exposed for building the "add widget" menu.
const widgetRegistry = _registry;

BoardWidgetDescriptor descriptorFor(BoardWidgetConfig config) =>
    _registry[config.runtimeType]!;
