import 'dart:convert';

import 'package:external_display/transfer_parameters.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:h3xboard/external_display/external_display_protocol.dart';
import 'package:h3xboard/external_display/external_idle_view.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/read_only_board.dart';
import 'package:h3xboard/views/board_screen/drawing_serialization.dart';

/// The root widget rendered inside the external-display isolate. It has no
/// access to the main app's state — everything it draws arrives over the
/// plugin's [transferParameters] bus and is rebuilt locally.
class ExternalDisplayView extends StatefulWidget {

  const ExternalDisplayView({super.key});

  @override
  State<ExternalDisplayView> createState() => _ExternalDisplayViewState();

}

/// A decoded board push, held aside while the screen fades to black so it can
/// be swapped in at the darkest point of the transition.
class _BoardContent {

  const _BoardContent(this.board, this.widgets, this.drawing);

  final Board board;
  final List<BoardWidget> widgets;
  final List<Map<String, dynamic>> drawing;

}

class _ExternalDisplayViewState extends State<ExternalDisplayView> with SingleTickerProviderStateMixin {

  static const Duration _fadeDuration = Duration(milliseconds: 300);
  final DrawingController _drawingController = DrawingController();
  late final AnimationController _fadeController;

  Board? _board;
  List<BoardWidget> _widgets = const [];

  // The transition target, applied once the screen is fully black:
  //   _pending != null  → show that board
  //   _pendingClear     → show the idle placeholder (board closed)
  // Also guards against rapid pushes for the same target restarting the fade.
  _BoardContent? _pending;
  bool _pendingClear = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: _fadeDuration)..addStatusListener(_onFadeStatus);
    transferParameters.addListener(_onParameters);
  }

  void _onParameters({required String action, dynamic value}) {
    switch (action) {
      case ExternalDisplayProtocol.actionBoard:
        _applyBoard(value);
      case ExternalDisplayProtocol.actionClear:
        _applyClear();
    }
  }

  /// Closing a board: fade through black, then reveal the idle placeholder.
  /// A no-op when already idle (nothing is showing to fade out).
  void _applyClear() {
    final alreadyIdle = _pendingClear || (_pending == null && _board == null);
    if (alreadyIdle) return;
    _pending = null;
    _pendingClear = true;
    _fadeController.forward(from: 0);
  }

  void _applyBoard(dynamic value) {
    if (value is! String) return;
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(value) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final board = Board.fromJson((payload[ExternalDisplayProtocol.keyBoard] as Map).cast<String, dynamic>());
    final widgets = (payload[ExternalDisplayProtocol.keyWidgets] as List)
        .map((e) => BoardWidget.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final drawing = (payload[ExternalDisplayProtocol.keyDrawing] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final content = _BoardContent(board, widgets, drawing);

    // Opening a board (idle → id) or switching sub-board (idA → idB) fades
    // through black; live edits to the same sub-board apply in place. A pending
    // clear counts as heading to idle, so a board arriving then fades in.
    final targetId = _pendingClear ? null : (_pending?.board.id ?? _board?.id);
    if (targetId != board.id) {
      _pending = content;
      _pendingClear = false;
      _fadeController.forward(from: 0);
    } else if (_fadeController.isAnimating || _pending != null) {
      // A fade to this board is already underway — refresh what will be shown
      // when it completes without restarting the animation.
      _pending = content;
    } else {
      _applyContent(content);
    }
  }

  /// Swaps to the idle placeholder, no transition.
  void _applyIdle() {
    _drawingController.clear();
    setState(() {
      _board = null;
      _widgets = const [];
    });
  }

  /// Swaps the visible board/widgets/drawing to [content], no transition.
  void _applyContent(_BoardContent content) {
    _drawingController.clear();
    final contents = restoreDrawingContents(content.drawing);
    if (contents.isNotEmpty) _drawingController.addContents(contents);
    setState(() {
      _board = content.board;
      _widgets = content.widgets;
    });
  }

  void _onFadeStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.completed:
        // Fully black: swap in the pending target, then fade it back in.
        _applyPending();
        _fadeController.reverse();
      case AnimationStatus.dismissed:
        // Faded back in. Apply anything that landed mid-fade.
        _applyPending();
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
    }
  }

  /// Applies whichever transition target is queued (a board, or idle), if any.
  void _applyPending() {
    if (_pendingClear) {
      _pendingClear = false;
      _applyIdle();
      return;
    }
    final pending = _pending;
    _pending = null;
    if (pending != null) _applyContent(pending);
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Stack(
        children: [
          // White bars behind the board; the board fits within, centered.
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
          if (board == null)
            const Positioned.fill(child: ExternalIdleView())
          else
            Positioned.fill(
              child: ReadOnlyBoard(
                board: board,
                widgets: _widgets,
                drawingController: _drawingController,
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
      ),
    );
  }

  @override
  void dispose() {
    transferParameters.removeListener(_onParameters);
    _fadeController.dispose();
    _drawingController.dispose();
    super.dispose();
  }

}
