import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/audio/board_audio_engine.dart';
import 'package:h3xboard/services/board_asset_resolver.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/file_picker_dialog.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/file_picker_kind.dart';
import 'package:h3xboard/views/board_screen/components/tabular_text.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_surface.dart';
import 'package:h3xboard/views/components/board_assets.dart';
import 'package:h3xboard/views/components/board_audio_scope.dart';
import 'package:h3xboard/views/components/dialogs/app_dialog.dart';
import 'package:h3xboard/views/components/file_format.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A media transport for one uploaded track: play/pause, stop, scrub, loop and
/// volume.
///
/// Where the [SoundPadWidget] is fire-and-forget, this is a thing you operate.
/// So unlike a pad it has a position, and that position has to survive being
/// mirrored to a screen whose clock disagrees with this one.
///
/// It does that by **anchoring on arrival**. When a config says the track is
/// playing, this starts at the position it was handed and counts forward on its
/// own clock. It never computes `now - startedAtEpochMs`, because that compares
/// two machines' clock offsets. A few seconds of skew is invisible on a
/// stopwatch and catastrophic on audio.
class AudioPlayerWidget extends StatefulWidget {

  /// Wide and short: a transport is a row of controls over a scrub bar.
  static const Size naturalSize = Size(560, 220);

  final String fileId;
  final String title;
  final double volume;
  final bool loop;

  /// Where the track sits: the paused position, or the position as of the last
  /// refresh while playing.
  final int positionMs;

  /// Null while paused. Watched, not read as a clock — see the class doc.
  final int? startedAtEpochMs;

  /// Cached at pick time so the scrub bar has a length before the bytes arrive.
  final int? durationMs;

  /// The MIME type this file was uploaded as, or null when it was configured
  /// before that was recorded. Decides whether the track can be streamed — see
  /// [BoardAudioEngine.canStream].
  final String? contentType;

  final void Function(int positionMs, int? startedAtEpochMs) onPlaybackChanged;
  final ValueChanged<bool> onLoopChanged;
  final ValueChanged<double> onVolumeChanged;

  const AudioPlayerWidget({
    super.key,
    required this.fileId,
    required this.title,
    required this.volume,
    required this.loop,
    required this.positionMs,
    required this.startedAtEpochMs,
    required this.durationMs,
    required this.contentType,
    required this.onPlaybackChanged,
    required this.onLoopChanged,
    required this.onVolumeChanged,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();

}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {

  /// How often the presenter re-publishes where the track has got to. That way a
  /// screen joining mid-track lands close to the right place rather than at the
  /// last pause. Cheap: one small runtime-only delta, excluded from undo.
  static const Duration _positionRefresh = Duration(seconds: 5);

  /// Drives the scrub bar while playing. Also runs on mirrors, which is the
  /// point — the audience watches the bar move even when this device is not the
  /// one making the sound.
  Timer? _ticker;
  Timer? _positionPublisher;

  SoundHandle? _handle;

  /// Where the track was when this device last started counting, and when that
  /// was **by this device's clock**. Together they are the position, without
  /// ever comparing clocks with the presenter.
  int _baseMs = 0;
  DateTime? _startedHere;

  /// Set while the user is dragging the scrub bar, so the ticker doesn't fight
  /// the thumb.
  double? _scrubbing;

  /// Set while a streamed track has run out of buffered audio and is waiting for
  /// the network. Shown on the transport so a stall reads as "still loading"
  /// rather than as a player that has stopped responding.
  bool _isBuffering = false;

  /// The streaming source this player opened, and the track it was opened for.
  ///
  /// Owned here because [BoardAudioEngine.streamingSource] does not cache. It
  /// hands back a `preserved` buffer holding the whole decoded track, and only
  /// the player that asked for one can free it. Kept between plays rather than
  /// reopened on each press. Preserved means the buffer is still seekable after
  /// it has finished, so a pause and a resume cost nothing. Reopening would
  /// instead download the track again and strand the previous buffer.
  AudioSource? _streamedSource;
  String? _streamedFileId;

  /// Set at the top of [dispose], because `mounted` is still true throughout it.
  bool _disposed = false;

  bool get _isPlaying => widget.startedAtEpochMs != null;

  Duration get _duration => Duration(milliseconds: widget.durationMs ?? 0);

  Duration get _position {
    final scrubbing = _scrubbing;
    if (scrubbing != null) return Duration(milliseconds: scrubbing.round());
    return audioPlayerPosition(
      baseMs: _baseMs,
      startedHere: _startedHere,
      now: DateTime.now(),
      durationMs: widget.durationMs,
    );
  }

  @override
  void initState() {
    super.initState();
    _baseMs = widget.positionMs;
    if (_isPlaying) _beginLocalPlayback();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_warm());
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.fileId != widget.fileId) {
      unawaited(_stopAudio());
      unawaited(_releaseStream());
      _baseMs = widget.positionMs;
      _startedHere = null;
      unawaited(_warm());
      _syncTimers();
      return;
    }

    final started = widget.startedAtEpochMs != oldWidget.startedAtEpochMs;
    final moved = widget.positionMs != oldWidget.positionMs;
    // A refresh while playing repeats the position it already told us about —
    // re-seeking on those would stutter the track every few seconds.
    final isRefresh = _isPlaying && oldWidget.startedAtEpochMs != null && moved;

    if (started || (moved && !isRefresh)) {
      _baseMs = widget.positionMs;
      if (_isPlaying) {
        _beginLocalPlayback();
      } else {
        _startedHere = null;
        unawaited(_stopAudio());
      }
    }

    if (widget.volume != oldWidget.volume) _applyVolume();
    _syncTimers();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _positionPublisher?.cancel();
    unawaited(_stopAudio());
    unawaited(_releaseStream());
    super.dispose();
  }

  /// Decodes ahead of the first press — but only for a track that will be
  /// loaded whole anyway.
  ///
  /// A streamable track is deliberately *not* warmed. Its whole point is to
  /// start without waiting for the file, and pre-fetching it would spend the
  /// download it exists to avoid.
  Future<void> _warm() async {
    if (widget.fileId.isEmpty || _streams) return;
    if (!BoardAudioScope.of(context).playsHere) return;
    final resolver = BoardAssets.maybeResolverOf(context);
    if (resolver == null) return;
    await BoardAudioEngine.instance.source(widget.fileId, () => resolver.load(widget.fileId));
  }

  /// Whether this track is fed progressively rather than loaded whole.
  bool get _streams => BoardAudioEngine.canStream(widget.contentType);

  /// Opens the source to play, streaming when the container allows it.
  ///
  /// The fallback is not an error path but the ordinary one. WAV and FLAC cannot
  /// be sniffed from a partial stream. The external-display store has nothing to
  /// stream from, and a track configured before `contentType` was recorded has
  /// nothing to go on. All three land on the whole-file loader, which works.
  Future<AudioSource?> _openSource(BoardAssetResolver resolver) async {
    final engine = BoardAudioEngine.instance;

    if (_streams) {
      final open = _streamedSource;
      if (open != null && _streamedFileId == widget.fileId) return open;
      try {
        final chunks = await resolver.openStream(widget.fileId);
        if (chunks != null) {
          final streamed = await engine.streamingSource(
            widget.fileId,
            chunks,
            onBuffering: (isBuffering) {
              if (mounted) setState(() => _isBuffering = isBuffering);
            },
          );
          if (streamed != null) {
            await _releaseStream();
            _streamedSource = streamed;
            _streamedFileId = widget.fileId;
            return streamed;
          }
        }
      } on Object catch (error, stackTrace) {
        debugPrint('AudioPlayer stream open failed, falling back: $error\n$stackTrace');
      }
    }

    return engine.source(widget.fileId, () => resolver.load(widget.fileId));
  }

  /// Starts counting from [_baseMs] using *this* device's clock, and — if this
  /// surface is the one meant to sound — starts the audio too.
  void _beginLocalPlayback() {
    _startedHere = DateTime.now();
    unawaited(_startAudio());
  }

  Future<void> _startAudio() async {
    await _stopAudio();
    if (!mounted || widget.fileId.isEmpty) return;
    if (!BoardAudioScope.of(context).playsHere) return;

    final resolver = BoardAssets.maybeResolverOf(context);
    if (resolver == null) return;

    final engine = BoardAudioEngine.instance;
    final source = await _openSource(resolver);
    if (!mounted || source == null || !_isPlaying) return;

    final handle = await engine.play(source, volume: widget.volume);
    if (handle == null) return;
    if (!mounted || !_isPlaying) {
      await engine.stopAll([handle]);
      return;
    }

    _handle = handle;
    try {
      SoLoud.instance
        ..setLooping(handle, widget.loop)
        ..seek(handle, Duration(milliseconds: _baseMs));
    } on Object {
      // Seeking past the end, or a source that can't seek: playing from the
      // start is a better outcome than not playing.
    }
  }

  Future<void> _stopAudio() async {
    // A stalled stream that is being torn down is no longer buffering, and
    // leaving the flag set would strand a spinner on a stopped player.
    //
    // `mounted` is not the guard it looks like during teardown. A State is
    // still mounted throughout its own dispose(), so [_disposed] is what keeps
    // this off the element that is on its way out.
    if (_isBuffering && mounted && !_disposed) setState(() => _isBuffering = false);
    _isBuffering = false;
    final handle = _handle;
    _handle = null;
    if (handle != null) await BoardAudioEngine.instance.stopAll([handle]);
  }

  /// Hands this player's streaming source back to the engine.
  ///
  /// Nothing else can: it was never cached by key, so it is freed here or not at
  /// all.
  Future<void> _releaseStream() async {
    final open = _streamedSource;
    _streamedSource = null;
    _streamedFileId = null;
    if (open != null) await BoardAudioEngine.instance.disposeStreamingSource(open);
  }

  void _applyVolume() {
    final handle = _handle;
    if (handle == null) return;
    try {
      SoLoud.instance.setVolume(handle, widget.volume);
    } on Object {
      // A voice that already ended is not worth reporting.
    }
  }

  void _syncTimers() {
    _ticker?.cancel();
    _positionPublisher?.cancel();
    if (!_isPlaying) {
      _ticker = null;
      _positionPublisher = null;
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {});
      _stopAtEnd();
    });
    // On a mirror `onPlaybackChanged` is a no-op, so this is inert there — the
    // ticker above is what a mirror actually needs.
    _positionPublisher = Timer.periodic(_positionRefresh, (_) {
      if (!mounted || !_isPlaying) return;
      widget.onPlaybackChanged(_position.inMilliseconds, widget.startedAtEpochMs);
    });
  }

  /// A track that has run out stops itself, so the transport doesn't sit
  /// claiming to play silence.
  void _stopAtEnd() {
    if (!audioPlayerHasFinished(position: _position, durationMs: widget.durationMs, loop: widget.loop)) return;
    widget.onPlaybackChanged(0, null);
  }

  void _togglePlay() {
    if (_isPlaying) {
      widget.onPlaybackChanged(_position.inMilliseconds, null);
    } else {
      widget.onPlaybackChanged(_baseMs, DateTime.now().millisecondsSinceEpoch);
    }
  }

  void _stop() => widget.onPlaybackChanged(0, null);

  void _onScrubEnd(double value) {
    setState(() => _scrubbing = null);
    widget.onPlaybackChanged(
      value.round(),
      // Restart the anchor so every receiver re-seeks rather than treating the
      // move as one of the periodic refreshes.
      _isPlaying ? DateTime.now().millisecondsSinceEpoch : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    final theme = FluentTheme.of(context);
    final transport = context.appTheme.buttons.transport;
    final hasTrack = widget.fileId.isNotEmpty;
    final totalMs = (widget.durationMs ?? 0).toDouble();

    return BoardWidgetSurface(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hasTrack ? (widget.title.isNotEmpty ? widget.title : loc.audioPlayer_untitled) : loc.audioPlayer_noTrack,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 26, color: Colors.white.withValues(alpha: hasTrack ? 0.92 : 0.45)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Button(
                style: transport,
                onPressed: hasTrack ? _togglePlay : null,
                // The spinner replaces the transport icon rather than sitting
                // beside it. A stalled stream is still "playing" as far as the
                // rest of the UI is concerned. And a pause button that does
                // nothing for two seconds is worse than one that says why.
                child: _isBuffering
                    ? const SizedBox(width: 28, height: 28, child: ProgressRing(strokeWidth: 3))
                    : Icon(_isPlaying ? LucideIcons.pause : LucideIcons.play, size: 28),
              ),
              Button(
                style: transport,
                onPressed: hasTrack ? _stop : null,
                child: const Icon(LucideIcons.square, size: 24),
              ),
              Button(
                style: transport,
                onPressed: hasTrack ? () => widget.onLoopChanged(!widget.loop) : null,
                child: Icon(
                  LucideIcons.repeat,
                  size: 24,
                  color: widget.loop ? theme.accentColor : null,
                ),
              ),
              const Spacer(),
              const Icon(LucideIcons.volume2, size: 20),
              SizedBox(
                width: 140,
                child: Slider(
                  value: widget.volume.clamp(0, 1),
                  onChanged: hasTrack ? widget.onVolumeChanged : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Slider(
            value: totalMs <= 0 ? 0 : _position.inMilliseconds.clamp(0, totalMs.round()).toDouble(),
            max: totalMs <= 0 ? 1 : totalMs,
            onChanged: hasTrack && totalMs > 0 ? (value) => setState(() => _scrubbing = value) : null,
            onChangeEnd: hasTrack && totalMs > 0 ? _onScrubEnd : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TabularText(formatAudioDuration(_position), style: const TextStyle(fontSize: 18)),
              TabularText(formatAudioDuration(_duration), style: const TextStyle(fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

}

/// Where a track has got to, counted from [startedHere] on **this** device's
/// clock rather than from the presenter's timestamp.
///
/// Pulled out of the widget so it can be tested against a clock that actually
/// moves. `tester.pump(duration)` advances Flutter's timers but not
/// `DateTime.now()`, so a position read straight from the wall clock inside
/// `build` is untestable. And this is the exact calculation most worth having a
/// test for.
///
/// [startedHere] null means paused, so the position is just [baseMs]. A
/// negative elapsed (the clock stepped backwards under us) counts as zero
/// rather than rewinding the track.
Duration audioPlayerPosition({
  required int baseMs,
  required DateTime? startedHere,
  required DateTime now,
  int? durationMs,
}) {
  if (startedHere == null) return Duration(milliseconds: baseMs);
  final elapsed = now.difference(startedHere).inMilliseconds;
  final position = baseMs + (elapsed < 0 ? 0 : elapsed);
  return Duration(milliseconds: durationMs == null ? position : position.clamp(0, durationMs));
}

/// Whether a track that has run out should stop itself, rather than sit there
/// claiming to play silence. A looping track is left alone: wrapping is the
/// engine's job, and stopping it would defeat the loop.
bool audioPlayerHasFinished({
  required Duration position,
  required int? durationMs,
  required bool loop,
}) {
  if (loop || durationMs == null || durationMs <= 0) return false;
  return position.inMilliseconds >= durationMs;
}

class AudioPlayerWidgetDescriptor extends BoardWidgetDescriptor {

  static const AudioPlayerWidgetDescriptor instance = AudioPlayerWidgetDescriptor._();
  const AudioPlayerWidgetDescriptor._();

  @override
  IconData get icon => LucideIcons.circlePlay;

  @override
  String get emoji => '🎵';

  @override
  String label(AppLocalizations localizations) => localizations.addWidgetMenu_audioPlayer;

  @override
  Size naturalSize(BoardWidgetConfig config) => AudioPlayerWidget.naturalSize;

  @override
  BoardWidgetConfig get defaultConfig => const AudioPlayerConfig();

  @override
  Widget buildWidget(BoardWidgetConfig config, void Function(BoardWidgetConfig) onConfigChanged) {
    final c = config as AudioPlayerConfig;
    return AudioPlayerWidget(
      fileId: c.fileId,
      title: c.title,
      volume: c.volume,
      loop: c.loop,
      positionMs: c.positionMs,
      startedAtEpochMs: c.startedAtEpochMs,
      durationMs: c.durationMs,
      contentType: c.contentType,
      onPlaybackChanged: (positionMs, startedAtEpochMs) =>
          onConfigChanged(c.copyWith(positionMs: positionMs, startedAtEpochMs: startedAtEpochMs)),
      onLoopChanged: (loop) => onConfigChanged(c.copyWith(loop: loop)),
      onVolumeChanged: (volume) => onConfigChanged(c.copyWith(volume: volume)),
    );
  }

  @override
  List<MenuFlyoutItemBase> settingsMenuItems(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) {
    final c = config as AudioPlayerConfig;
    final loc = context.localizations;
    return [
      MenuFlyoutItem(
        leading: const Icon(LucideIcons.audioLines, size: 16),
        text: Text(c.fileId.isEmpty ? loc.audioPlayerSettingsMenu_choose : loc.audioPlayerSettingsMenu_replace),
        onPressed: () => unawaited(_pickTrack(context, c, onChange)),
      ),
    ];
  }

  @override
  VoidCallback? editAction(
    BuildContext context,
    BoardWidgetConfig config,
    void Function(BoardWidgetConfig) onChange,
  ) =>
      () => unawaited(_pickTrack(context, config as AudioPlayerConfig, onChange));

  static Future<void> _pickTrack(
    BuildContext context,
    AudioPlayerConfig config,
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
      onChange(config.copyWith(
        fileId: '',
        title: '',
        durationMs: null,
        contentType: null,
        positionMs: 0,
        startedAtEpochMs: null,
      ));
      return;
    }

    onChange(await configForFile(
      fileService,
      fileId,
      base: config,
      fileName: result.file?.fileName,
      contentType: result.file?.contentType,
    ));
  }

  /// The config for the track [fileId]: its id, a title from the file's own
  /// name, and its length. The length is resolved at pick time, so the scrub bar
  /// has a scale before the first play. Resolving it here also makes the length
  /// part of the edit, rather than a mutation that would land in undo history
  /// the first time someone presses play. Shared with the board's drag & drop,
  /// like the image widget's.
  static Future<AudioPlayerConfig> configForFile(
    H3xBoardFileService fileService,
    String fileId, {
    AudioPlayerConfig base = const AudioPlayerConfig(),
    String? fileName,
    String? contentType,
  }) async {
    final engine = BoardAudioEngine.instance;
    final source = await engine.source(fileId, () => fileService.downloadCached(fileId));
    final duration = source == null ? null : engine.lengthOf(source);
    return base.copyWith(
      fileId: fileId,
      // Always the new file's name. A player's title is never typed by the
      // user: the settings menu offers only choose/replace, no rename. So there
      // is nothing here to protect, and keeping the previous title would label
      // the new track with the old one's name.
      //
      // Falls back to empty rather than to [base.title] when the caller has no
      // name to offer. The widget renders that as "Untitled", which is at least
      // not a lie.
      title: captionForFileName(fileName),
      durationMs: duration?.inMilliseconds,
      contentType: contentType,
      // A new track starts at its beginning, whatever the old one was doing.
      positionMs: 0,
      startedAtEpochMs: null,
    );
  }


}
