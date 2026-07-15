import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/live_share/live_board_receiver.dart';
import 'package:h3xboard/views/board_screen/components/read_only_board.dart';

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

  const LiveBoardView({
    super.key,
    required this.messages,
    required this.placeholder,
    this.onGapDetected,
  });

  @override
  State<LiveBoardView> createState() => _LiveBoardViewState();

}

class _LiveBoardViewState extends State<LiveBoardView> with SingleTickerProviderStateMixin {

  static const Duration _fadeDuration = Duration(milliseconds: 300);

  final LiveBoardReceiver _receiver = LiveBoardReceiver();
  late final AnimationController _fadeController;
  StreamSubscription<LiveShareMessage>? _subscription;

  // Messages held back while the screen fades to black, applied in order at
  // the darkest point. non-null = a fade-out is underway.
  List<LiveShareMessage>? _heldBack;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: _fadeDuration)..addStatusListener(_onFadeStatus);
    _receiver
      ..onGapDetected = _onGap
      ..addListener(_onReceiverChanged);
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

  void _onReceiverChanged() => setState(() {});

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
            child: ReadOnlyBoard(
              board: board,
              widgets: _receiver.widgets,
              drawingController: _receiver.drawingController,
              inProgress: _receiver.inProgress,
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
