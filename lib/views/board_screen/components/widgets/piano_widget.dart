import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/piano_audio.dart';
import 'package:h3xboard/widgets/app_menu_flyout.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Semitone offset (relative to the octave's C) for each of the 7 white keys.
const List<int> _whiteSemitones = [0, 2, 4, 5, 7, 9, 11];

// Black keys, described by the index of the white key they sit after within an
// octave and their semitone offset (C#, D#, F#, G#, A#).
const List<({int afterWhite, int semitone})> _blackKeyDefs = [
  (afterWhite: 0, semitone: 1),
  (afterWhite: 1, semitone: 3),
  (afterWhite: 3, semitone: 6),
  (afterWhite: 4, semitone: 8),
  (afterWhite: 5, semitone: 10),
];

class PianoWidget extends StatefulWidget {

  // The keyboard's natural size scales with the octave count, so more octaves
  // make the widget wider rather than cramming thinner keys into a fixed box.
  static const double octaveWidth = 360;
  static const double height = 150;

  static Size sizeForOctaves(int octaves) => Size(octaveWidth * octaves, height);

  final int octaves;

  const PianoWidget({super.key, this.octaves = 1});

  @override
  State<PianoWidget> createState() => _PianoWidgetState();

}

class _PianoWidgetState extends State<PianoWidget> {

  final Set<int> _pressed = {};

  void _press(int midiNote) {
    setState(() => _pressed.add(midiNote));
    unawaited(PianoAudio.instance.playNote(midiNote));
  }

  void _release(int midiNote) {
    setState(() => _pressed.remove(midiNote));
  }

  @override
  Widget build(BuildContext context) {
    final octaves = widget.octaves;
    final size = PianoWidget.sizeForOctaves(octaves);

    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xE6111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24), width: 1),
      ),
      // LayoutBuilder gives the exact inner size (after padding + border), so the
      // keys always fit precisely without overflowing.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final whiteCount = octaves * 7;
          final whiteWidth = constraints.maxWidth / whiteCount;
          final blackWidth = whiteWidth * 0.62;
          final blackHeight = constraints.maxHeight * 0.62;

          final whiteKeys = <Widget>[];
          for (var octave = 0; octave < octaves; octave++) {
            for (final semitone in _whiteSemitones) {
              final midiNote = PianoAudio.lowestMidi + octave * 12 + semitone;
              whiteKeys.add(Expanded(child: _buildWhiteKey(midiNote)));
            }
          }

          final blackKeys = <Widget>[];
          for (var octave = 0; octave < octaves; octave++) {
            for (final def in _blackKeyDefs) {
              final globalWhiteIndex = octave * 7 + def.afterWhite;
              final midiNote = PianoAudio.lowestMidi + octave * 12 + def.semitone;
              final left = (globalWhiteIndex + 1) * whiteWidth - blackWidth / 2;
              blackKeys.add(Positioned(
                left: left,
                top: 0,
                child: _buildBlackKey(midiNote, blackWidth, blackHeight),
              ));
            }
          }

          return SizedBox.expand(
            child: Stack(
              children: [
                // Stretch fills each white key to the full keyboard height;
                // Expanded distributes the width evenly across the octaves.
                Positioned.fill(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: whiteKeys),
                ),
                ...blackKeys,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWhiteKey(int midiNote) {
    final pressed = _pressed.contains(midiNote);
    return GestureDetector(
      onTapDown: (_) => _press(midiNote),
      onTapUp: (_) => _release(midiNote),
      onTapCancel: () => _release(midiNote),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pressed ? const Color(0xFFB9D2FF) : const Color(0xFFF5F5F7),
          border: Border.all(color: Colors.black.withValues(alpha: 0.25), width: 0.5),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        ),
      ),
    );
  }

  Widget _buildBlackKey(int midiNote, double width, double height) {
    final pressed = _pressed.contains(midiNote);
    return GestureDetector(
      onTapDown: (_) => _press(midiNote),
      onTapUp: (_) => _release(midiNote),
      onTapCancel: () => _release(midiNote),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: pressed ? const Color(0xFF5A6072) : const Color(0xFF14181F),
          border: Border.all(color: Colors.black.withValues(alpha: 0.6), width: 0.5),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
        ),
      ),
    );
  }

}

class PianoWidgetDescriptor extends BoardWidgetDescriptor {

  static const PianoWidgetDescriptor instance = PianoWidgetDescriptor._();
  const PianoWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.piano;

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_piano;

  @override
  Size naturalSize(BoardWidgetConfig config) => PianoWidget.sizeForOctaves((config as PianoConfig).octaves);

  @override
  BoardWidgetConfig get defaultConfig => const PianoConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as PianoConfig;
    return PianoWidget(octaves: c.octaves);
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as PianoConfig;
    final l = context.localizations;

    RadioMenuFlyoutItem<int> octavesItem(int value, String label) {
      return RadioMenuFlyoutItem<int>(
        value: value,
        groupValue: c.octaves,
        text: Text(label),
        onChanged: (v) => onChange(c.copyWith(octaves: v)),
      );
    }

    return [
      AppMenuFlyoutSubItem(
        text: Text(l.pianoSettingsMenu_octaves),
        items: (_) => [
          octavesItem(1, l.pianoSettingsMenu_octaves1),
          octavesItem(2, l.pianoSettingsMenu_octaves2),
        ],
      ),
    ];
  }

}
