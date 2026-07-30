import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/analog_clock_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/clock_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/geodreieck_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/image_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/memo_note_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/piano_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/qr_code_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/ruler_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/stopwatch_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/text_box_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/timer_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/todo_list_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/traffic_light_widget.dart';

// Abstract descriptor for a board widget type. Each widget file provides a
// concrete singleton implementation that encapsulates construction, natural
// size, and settings menu items. board.dart and manipulable_board_widget.dart
// dispatch through descriptorFor() and never contain type-specific switches.
abstract class BoardWidgetDescriptor {

  const BoardWidgetDescriptor();

  IconData get icon;
  String label(AppLocalizations localizations);
  Size naturalSize(BoardWidgetConfig config);
  BoardWidgetConfig get defaultConfig;
  // [onConfigChanged] lets interactive widgets persist config mutations made on
  // the canvas itself (e.g. ticking a to-do item). Most widgets ignore it.
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged);
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  );

  // Whether the widget appears in the "add widget" catalog. Widgets reached from
  // their own toolbar button (the text label lives with the annotation tools) opt
  // out so they aren't offered in two places.
  bool get showInCatalog => true;

  // Whether the widget gets the floating header bar (drag handle, title, settings,
  // Arrange toggle, remove) in Select mode. Widgets that are meant to read as bare
  // board content rather than as a boxed widget opt out; they must also be
  // [isDraggableInSelectMode], since the header is otherwise the only way to move
  // them. Settings and delete stay reachable via long-press / right-click.
  bool get hasHeaderBar => true;

  // Whether the widget can be dragged by its body in Select mode, instead of only
  // by its header or from inside Arrange mode.
  bool get isDraggableInSelectMode => false;

  // Whether a single tap on the body in Select mode puts the widget into Arrange
  // mode. Widgets without a header bar have no pencil toggle to get there, so a
  // tap on the body is what brings out their resize and rotate handles.
  bool get entersArrangeOnTap => false;

  // Whether the body is dimmed and its interactions paused while the widget is
  // being arranged. Widgets that stay usable with their handles out — a text
  // label being typed into in place — opt out.
  bool get isInertWhileArranging => true;

  // The widget's primary inline-edit action, invoked when the body is double-clicked.
  // Returns null for widgets with nothing to edit (e.g. clocks). Widgets that override
  // this typically also expose the same action as a settings menu item.
  VoidCallback? editAction(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) =>
      null;

}

// The single place that maps config types to their descriptors.
// To add a new widget type: add an entry here and nowhere else.
const Map<Type, BoardWidgetDescriptor> _registry = {
  DigitalClockConfig: DigitalClockWidgetDescriptor.instance,
  AnalogClockConfig: AnalogClockWidgetDescriptor.instance,
  TrafficLightConfig: TrafficLightWidgetDescriptor.instance,
  StopwatchConfig: StopwatchWidgetDescriptor.instance,
  TimerConfig: TimerWidgetDescriptor.instance,
  MemoNoteConfig: MemoNoteWidgetDescriptor.instance,
  TextBoxConfig: TextBoxWidgetDescriptor.instance,
  PianoConfig: PianoWidgetDescriptor.instance,
  TodoListConfig: TodoListWidgetDescriptor.instance,
  RulerConfig: RulerWidgetDescriptor.instance,
  GeodreieckConfig: GeodreieckWidgetDescriptor.instance,
  ImageConfig: ImageWidgetDescriptor.instance,
  QrCodeConfig: QrCodeWidgetDescriptor.instance,
};

// All registered descriptors, exposed for building the "add widget" menu.
const widgetRegistry = _registry;

BoardWidgetDescriptor descriptorFor(BoardWidgetConfig config) =>
    _registry[config.runtimeType]!;
