import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/audio/board_audio_engine.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/emoji_picker_dialog.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/file_picker_dialog.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/file_picker_kind.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_surface.dart';
import 'package:h3xboard/views/board_screen/components/widgets/emoji_image.dart';
import 'package:h3xboard/views/components/board_assets.dart';
import 'package:h3xboard/views/components/board_audio_scope.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// One button of a soundboard: an emoji you recognise the sound by, its name
/// underneath, and a stop badge that only exists while it is making noise.
///
/// Tapping the body fires the sound. Tapping again layers a second voice over
/// the first rather than restarting it. That layering is how a sampler pad
/// behaves, and what makes a row of these usable as an instrument. The badge
/// stops every voice this pad has going at once.
///
/// The body is the trigger and nothing else — dragging happens on the header
/// bar. A pad you drag by its face is a pad you fire every time you move it.
class SoundPadWidget extends StatefulWidget {

  /// Squarish: the emoji is the thing being recognised, and the label is a
  /// caption under it rather than a second column.
  static const Size naturalSize = Size(260, 300);

  final String fileId;
  final String label;
  final String emoji;
  final double volume;

  /// Advances by one per tap. **Watched, not called**: the tap only bumps the
  /// seed, and playing happens when the changed seed comes back through config.
  ///
  /// That indirection is what makes one code path serve all three surfaces. The
  /// presenter, the external display and every web viewer all see the same seed
  /// change. Each asks its own [BoardAudioPolicy] whether it is the one meant to
  /// sound. So routing audio to the classroom TV needs no separate "play
  /// remotely" path, just a different answer to the same question.
  final int triggerSeed;

  /// Advances by one per stop press. Watched rather than called so the stop
  /// reaches every mirror the same way a trigger does — see [SoundPadConfig].
  final int stopSeed;

  /// Fires the sound. A no-op on a read-only mirror, exactly like the
  /// stopwatch's `onChanged`.
  final VoidCallback onTrigger;

  /// Silences this pad's voices.
  final VoidCallback onStop;

  const SoundPadWidget({
    super.key,
    required this.fileId,
    required this.label,
    required this.emoji,
    required this.volume,
    required this.triggerSeed,
    required this.stopSeed,
    required this.onTrigger,
    required this.onStop,
  });

  @override
  State<SoundPadWidget> createState() => _SoundPadWidgetState();

}

class _SoundPadWidgetState extends State<SoundPadWidget> {

  /// Every voice this pad currently has sounding. A list rather than a single
  /// handle because re-tapping layers rather than replaces.
  final List<SoundHandle> _voices = [];

  /// Runs only while [_voices] is non-empty, to notice voices that ended on
  /// their own so the badge disappears with the sound.
  Timer? _reaper;

  /// Set while a trigger has gone out that this device deliberately isn't
  /// playing, so the pad can still confirm the tap landed.
  Timer? _sentFlash;
  bool _showSentToScreen = false;

  bool get _isPlaying => _voices.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_warm());
  }

  /// Decodes this pad's sound ahead of the first tap.
  ///
  /// Without it the first press pays for a download and a decode before making
  /// any noise. On a shared screen that first press is exactly the one that most
  /// needs to be instant. Skipped on a surface that isn't going to play. Thirty
  /// student laptops watching a lesson should not each pull down a soundboard
  /// they were never going to sound.
  Future<void> _warm() async {
    if (widget.fileId.isEmpty) return;
    if (!BoardAudioScope.of(context).playsHere) return;
    final resolver = BoardAssets.maybeResolverOf(context);
    if (resolver == null) return;
    await BoardAudioEngine.instance.source(widget.fileId, () => resolver.load(widget.fileId));
  }

  @override
  void didUpdateWidget(SoundPadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Edges, not states: it is the *change* that acts. Comparing seeds rather
    // than reading a flag is what lets two taps in a row both land. The seed
    // comparison is also what lets a mirror act on a trigger it didn't initiate.
    if (oldWidget.triggerSeed != widget.triggerSeed) _onTriggered();
    if (oldWidget.stopSeed != widget.stopSeed) unawaited(_stopAll());
    // Pointing the pad at a different sound abandons whatever the old one was
    // playing. Otherwise the badge would offer to stop a sound that is no longer
    // this pad's.
    if (oldWidget.fileId != widget.fileId) {
      unawaited(_stopAll());
      unawaited(_warm());
    }
  }

  /// A trigger arrived — from this device's own tap, or from the presenter if
  /// this is a mirror. Whether it makes a sound is the surface's call, not the
  /// pad's.
  void _onTriggered() {
    final policy = BoardAudioScope.of(context);
    // The hidden twin of a pad shown full screen sees the same seed change as
    // the copy on screen. Only one of them may act, and it is not this one.
    // Acting here too would play every tap twice, and flashing would confirm a
    // trigger the user cannot see.
    if (policy.isInert) return;
    if (policy.playsHere) {
      unawaited(_fire());
    } else {
      _flashSentToScreen();
    }
  }

  /// Confirms a trigger this device isn't playing.
  ///
  /// Deliberately *not* a progress bar. Sound routed to a shared screen leaves
  /// this device with nothing to observe. The relay is one-way, so this device
  /// cannot know whether the screen actually made a noise. Animating progress
  /// would claim knowledge it doesn't have.
  void _flashSentToScreen() {
    _sentFlash?.cancel();
    setState(() => _showSentToScreen = true);
    _sentFlash = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showSentToScreen = false);
    });
  }

  @override
  void dispose() {
    _sentFlash?.cancel();
    _reaper?.cancel();
    // Removing a pad mid-sound must not leave the sound running.
    if (_voices.isNotEmpty) unawaited(BoardAudioEngine.instance.stopAll(List.of(_voices)));
    super.dispose();
  }

  /// Polling rather than SoLoud's `allInstancesFinished`, which fires per audio
  /// *source*. Two pads pointing at the same file share one source, so that
  /// stream would hold one pad's badge open until the other pad also went quiet.
  /// A handle is this pad's alone, and the timer only exists while one is live.
  void _syncReaper() {
    if (_voices.isEmpty) {
      _reaper?.cancel();
      _reaper = null;
      return;
    }
    _reaper ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
      final ended = _voices.where((h) => !SoLoud.instance.getIsValidVoiceHandle(h)).toList();
      if (ended.isEmpty) return;
      _voices.removeWhere(ended.contains);
      if (mounted) setState(_syncReaper);
    });
  }

  Future<void> _stopAll() async {
    if (_voices.isEmpty) return;
    final playing = List.of(_voices);
    _voices.clear();
    if (mounted) setState(_syncReaper);
    await BoardAudioEngine.instance.stopAll(playing);
  }

  Future<void> _fire() async {
    final resolver = BoardAssets.maybeResolverOf(context);
    if (widget.fileId.isEmpty || resolver == null) return;

    final engine = BoardAudioEngine.instance;
    final source = await engine.source(widget.fileId, () => resolver.load(widget.fileId));
    if (!mounted || source == null) return;

    final handle = await engine.play(source, volume: widget.volume);
    // Null when audio is unavailable, or when SoLoud declined the voice because
    // the board is already at its 16-voice ceiling. Neither is an error worth
    // surfacing — the pad simply doesn't sound this time.
    if (handle == null) return;

    // The pad can be removed while the voice is being created. dispose() stops
    // only what reached [_voices]. So a handle arriving after that has to be
    // stopped here, or it plays to the end with nothing able to reach it.
    if (!mounted) {
      await engine.stopAll([handle]);
      return;
    }

    setState(() {
      _voices.add(handle);
      _syncReaper();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    final hasSound = widget.fileId.isNotEmpty;
    final caption = widget.label.isNotEmpty ? widget.label : loc.soundPad_noSound;

    return BoardWidgetSurface(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: GestureDetector(
        // Opaque so the whole card is the trigger, including the padding around
        // the emoji — a pad with dead zones is a pad that feels broken.
        behavior: HitTestBehavior.opaque,
        onTap: hasSound ? widget.onTrigger : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: hasSound ? 1 : 0.35,
                      child: EmojiImage(emoji: widget.emoji, isScaled: true),
                    ),
                  ),
                  if (_isPlaying)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: _StopBadge(voiceCount: _voices.length, onPressed: widget.onStop),
                    )
                  else if (_showSentToScreen)
                    const Positioned(top: -6, right: -6, child: _SentToScreenBadge()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              caption,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                color: Colors.white.withValues(alpha: hasSound ? 0.92 : 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// The stop control, drawn on the emoji's top-right corner and present only
/// while the pad has voices.
///
/// It sits on the corner rather than in the header bar because it belongs to the
/// sound, not to the widget. The header is where you delete and configure a pad.
/// Reaching there to silence one is both further away and easy to confuse with
/// removing it.
class _StopBadge extends StatelessWidget {

  final int voiceCount;
  final VoidCallback onPressed;

  const _StopBadge({required this.voiceCount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return GestureDetector(
      // Swallows the tap so stopping never doubles as another trigger.
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.accentColor.darker,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.square, size: 20, color: Colors.white),
            // Only worth showing once there is more than one, where it explains
            // why one press silences several sounds at once.
            if (voiceCount > 1) ...[
              const SizedBox(width: 6),
              Text('$voiceCount', style: const TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ],
        ),
      ),
    );
  }

}

/// Shown briefly when a trigger went out but this device isn't the one playing
/// it, so a tap never looks like it did nothing.
class _SentToScreenBadge extends StatelessWidget {

  const _SentToScreenBadge();

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(LucideIcons.tv, size: 20, color: Colors.white),
      ),
    );
  }

}

class SoundPadWidgetDescriptor extends BoardWidgetDescriptor {

  static const SoundPadWidgetDescriptor instance = SoundPadWidgetDescriptor._();
  const SoundPadWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.volume2;

  @override
  String get emoji => '🥁';

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_soundPad;

  @override
  Size naturalSize(BoardWidgetConfig config) => SoundPadWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const SoundPadConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as SoundPadConfig;
    return SoundPadWidget(
      fileId: c.fileId,
      label: c.label,
      emoji: c.emoji,
      volume: c.volume,
      triggerSeed: c.triggerSeed,
      stopSeed: c.stopSeed,
      onTrigger: () => onConfigChanged(c.copyWith(triggerSeed: c.triggerSeed + 1)),
      onStop: () => onConfigChanged(c.copyWith(stopSeed: c.stopSeed + 1)),
    );
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as SoundPadConfig;
    final loc = context.localizations;
    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.audioLines, size: 16),
        text: Text(c.fileId.isEmpty ? loc.soundPadSettingsMenu_choose : loc.soundPadSettingsMenu_replace),
        onPressed: () => unawaited(_pickSound(context, c, onChange)),
      ),
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.smile, size: 16),
        text: Text(loc.soundPadSettingsMenu_changeEmoji),
        onPressed: () => unawaited(_pickEmoji(context, c, onChange)),
      ),
    ];
  }

  static Future<void> _pickSound(
    BuildContext context,
    SoundPadConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) async {
    final fileService = GetIt.I<H3xBoardFileService>();
    final result = await showAppDialog<FilePickerResult>(
      context: context,
      builder: (_) => FilePickerDialog(
        apiClient: GetIt.I<H3xBoardApiClient>(),
        fileService: fileService,
        kind: FilePickerKind.sounds,
        initialFolder: soundsFolder,
        currentFileId: config.fileId.isEmpty ? null : config.fileId,
        title: context.localizations.soundPicker_title,
      ),
    );
    if (result == null) return;

    final fileId = result.fileId;
    if (fileId == null || fileId.isEmpty) {
      onChange(config.copyWith(fileId: '', label: '', durationMs: null));
      return;
    }

    onChange(await configForFile(fileService, fileId, base: config, fileName: result.file?.fileName));
  }

  /// The [SoundPadConfig] for the sound [fileId]: its id, a label defaulting to
  /// the file's own name, and its length.
  ///
  /// The length is resolved **here**, at pick time, rather than on first play.
  /// That keeps it part of the edit. Resolving on first play would instead be a
  /// config mutation, landing in undo history the first time someone taps the
  /// pad. Shared with the board's drag & drop for the same reason
  /// `ImageWidgetDescriptor.configForFile` is: a dropped sound should arrive
  /// labelled exactly like a picked one.
  static Future<SoundPadConfig> configForFile(
    H3xBoardFileService fileService,
    String fileId, {
    SoundPadConfig base = const SoundPadConfig(),
    String? fileName,
  }) async {
    final engine = BoardAudioEngine.instance;
    final source = await engine.source(fileId, () => fileService.downloadCached(fileId));
    final duration = source == null ? null : engine.lengthOf(source);
    return base.copyWith(
      fileId: fileId,
      // Always the new file's name. A pad cannot be renamed, so the label only
      // ever describes the sound it points at. Keeping the old one would caption
      // the new sound with the previous one's name.
      label: captionForFileName(fileName),
      durationMs: duration?.inMilliseconds,
    );
  }


  static Future<void> _pickEmoji(
    BuildContext context,
    SoundPadConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) async {
    final picked = await showAppDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => EmojiPickerDialog(selected: config.emoji),
    );
    if (picked == null) return;
    onChange(config.copyWith(emoji: picked));
  }

}
