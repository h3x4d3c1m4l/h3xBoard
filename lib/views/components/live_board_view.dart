import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/live_share/live_board_receiver.dart';
import 'package:h3xboard/views/board_screen/components/read_only_board.dart';
import 'package:h3xboard/views/components/board_audio_scope.dart';

/// Renders a live-shared board from a stream of [LiveShareMessage]s: the
/// shared display half of the live-share protocol, used by the
/// external-display isolate and the web viewer screen. Owns a
/// [LiveBoardReceiver] and the board-switch transition; shows [placeholder]
/// while nothing is being presented.
///
/// Opening a board or switching sub-boards fades through black: the
/// triggering snapshot (and everything behind it) is held back while the
/// screen darkens and applied at the darkest point. Same-board updates apply
/// in place, live.
///
/// Asset resolution (image widgets, background images) comes from the
/// enclosing `BoardAssets` scope — wrap this view in one when the default
/// authenticated fallback doesn't apply.
class LiveBoardView extends StatefulWidget {

  final Stream<LiveShareMessage> messages;

  /// Shown when no board is being presented (idle / waiting, per caller).
  final Widget placeholder;

  /// Fired when a sequence gap froze the mirror; the transport should request
  /// a resync so the presenter sends a fresh snapshot.
  final VoidCallback? onGapDetected;

  /// Fired when the board starts or stops holding widgets this build can't
  /// draw. Reported upward rather than drawn here so the host can place the
  /// notice among its own overlays instead of stacking two banners.
  final ValueChanged<bool>? onUnsupportedContentChanged;

  /// Whether *this* screen has had its sound switched on.
  ///
  /// Only half the permission: the presenter must also have routed audio to
  /// viewers. Omitting it means this surface never plays. That is the right
  /// answer for the external display: it shares the host's audio device.
  /// Playing here would double the presenter's sound rather than move it.
  final bool Function()? soundEnabledHere;

  /// Fired when the presenter changes where audio is routed, so the host can
  /// tell the viewer whether its sound switch would currently do anything.
  final ValueChanged<bool>? onAudioRoutingChanged;

  const LiveBoardView({
    super.key,
    required this.messages,
    required this.placeholder,
    this.onGapDetected,
    this.onUnsupportedContentChanged,
    this.soundEnabledHere,
    this.onAudioRoutingChanged,
  });

  @override
  State<LiveBoardView> createState() => _LiveBoardViewState();

}

class _LiveBoardViewState extends State<LiveBoardView> with SingleTickerProviderStateMixin {

  static const Duration _fadeDuration = Duration(milliseconds: 300);

  final LiveBoardReceiver _receiver = LiveBoardReceiver();

  /// Built once and kept: the policy reads through to the notifier and the
  /// host's callback, so it never needs replacing and can't churn the scope.
  late final BoardAudioPolicy _audioPolicy = ViewerBoardAudioPolicy(
    presenterRoutedToViewers: () => _receiver.audioToViewers.value,
    soundEnabledHere: widget.soundEnabledHere ?? _never,
  );

  static bool _never() => false;
  late final AnimationController _fadeController;
  StreamSubscription<LiveShareMessage>? _subscription;

  // Messages held back while the screen fades to black, applied in order at
  // the darkest point. non-null = a fade-out is underway.
  List<LiveShareMessage>? _heldBack;

  // Last value handed to onUnsupportedContentChanged, so it fires on the edge
  // rather than on every frame of a stroke.
  bool _unsupportedReported = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: _fadeDuration)..addStatusListener(_onFadeStatus);
    _receiver
      ..onGapDetected = _onGap
      ..addListener(_onReceiverChanged);
    _receiver.audioToViewers.addListener(_onAudioRoutingChanged);
    _subscription = widget.messages.listen(_onMessage);
  }

  @override
  void didUpdateWidget(LiveBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages != oldWidget.messages) {
      _subscription?.cancel();
      _subscription = widget.messages.listen(_onMessage);
    }
  }

  void _onGap() => widget.onGapDetected?.call();

  void _onAudioRoutingChanged() => widget.onAudioRoutingChanged?.call(_receiver.audioToViewers.value);

  void _onReceiverChanged() {
    setState(() {});
    final unsupported = _receiver.hasUnsupportedWidgets;
    if (unsupported == _unsupportedReported) return;
    _unsupportedReported = unsupported;
    widget.onUnsupportedContentChanged?.call(unsupported);
  }

  void _onMessage(LiveShareMessage message) {
    final heldBack = _heldBack;
    if (heldBack != null) {
      // Mid fade-out: whatever arrives now becomes part of what is revealed.
      heldBack.add(message);
      return;
    }
    if (_isBoardTransition(message)) {
      _heldBack = [message];
      _fadeController.forward(from: 0);
      return;
    }
    _receiver.apply(message);
  }

  /// Whether [message] changes what board is on screen (open, switch, close),
  /// which warrants the fade-through-black rather than an in-place update.
  bool _isBoardTransition(LiveShareMessage message) {
    final currentId = _receiver.board?.id;
    return switch (message) {
      LiveShareSnapshot m => m.board.id != currentId,
      LiveShareClear _ => currentId != null,
      _ => false,
    };
  }

  void _onFadeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // Fully black: apply everything held back, then fade the result in.
    // Messages arriving during the reveal apply live — they belong to the
    // board being revealed (a new transition would just start a new fade).
    final heldBack = _heldBack;
    _heldBack = null;
    if (heldBack != null) {
      for (final message in heldBack) {
        _receiver.apply(message);
      }
    }
    _fadeController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final board = _receiver.board;
    return Stack(
      children: [
        // White bars behind the board; the board fits within, centered.
        const Positioned.fill(child: ColoredBox(color: Colors.white)),
        if (board == null)
          Positioned.fill(child: widget.placeholder)
        else
          Positioned.fill(
            child: BoardAudioScope(
              policy: _audioPolicy,
              child: ReadOnlyBoard(
                board: board,
                widgets: _receiver.widgets,
                drawingController: _receiver.drawingController,
                inProgress: _receiver.inProgress,
                laser: _receiver.laser,
                fullScreenWidget: _receiver.fullScreenWidget,
              ),
            ),
          ),
        // Crossfade-through-black overlay. Positioned.fill so it actually
        // covers the screen — a bare ColoredBox in a loose Stack is 0×0.
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _fadeController,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _fadeController.dispose();
    _receiver.dispose();
    super.dispose();
  }

}
