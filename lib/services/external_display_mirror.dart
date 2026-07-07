import 'dart:async';
import 'dart:convert';

import 'package:external_display/external_display.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/external_display/external_display_protocol.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:mobx/mobx.dart';

/// Owns the connection to a physically-attached external display and mirrors
/// the active board onto it, read-only. Registered as an app-wide singleton and
/// started once at launch, so the external screen shows the idle placeholder as
/// soon as it is plugged in — even before any board is opened (e.g. on the login
/// screen). The board screen pushes board content while it is active and blanks
/// back to idle when it closes.
///
/// The external screen runs in a separate isolate ([externalDisplayMain]); the
/// only way to reach it is the plugin's `sendParameters` bus, so every push
/// serializes the board render state to JSON.
class ExternalDisplayMirror {

  bool _started = false;
  bool _connected = false;
  bool _ready = false;

  // Observable mirror of [_ready], so UI (e.g. the Settings dialog) can react
  // live to plug/unplug and reflect whether an external display is attached.
  final Observable<bool> _connectedObservable = Observable(false);

  // The most recent board payload, retained so we can (a) flush it once the
  // external view signals readiness and (b) re-send it when a display is
  // plugged in mid-session. Null means "no board open" → idle placeholder.
  String? _pendingBoardJson;
  bool _pendingClear = false;

  // Currently-applied external resolution (pixels); null = auto (largest mode).
  int? _width;
  int? _height;
  ReactionDisposer? _resolutionReactionDisposer;

  void Function(String action, Object? value)? _sendOverride;

  ExternalDisplayMirror();

  /// Whether an external display is currently attached and actively mirroring.
  /// Observable — reading it inside a MobX `reaction`/`Observer` tracks changes.
  bool get isConnected => _connectedObservable.value;

  /// Updates [_ready] and keeps the observable connection state in sync.
  void _setReady(bool value) {
    _ready = value;
    runInAction(() => _connectedObservable.value = value);
  }

  /// Test seam: route sends through [override] instead of the platform plugin.
  @visibleForTesting
  set sendOverride(void Function(String action, Object? value)? override) => _sendOverride = override;

  /// Start listening for plug/unplug and connect if a display is already
  /// attached. Idempotent: called once at app launch, so repeat calls are no-ops.
  Future<void> start() async {
    // The external_display plugin has no web implementation; even touching the
    // `externalDisplay` singleton wires up the `monitorStateListener` EventChannel
    // in its constructor, which throws MissingPluginException on web. Skip it.
    if (kIsWeb) return;
    if (_started) return;
    _started = true;
    externalDisplay.addStatusListener(_onDisplayStatusChange);
    // Seed the preferred resolution and re-apply it whenever the user changes it
    // in Settings (loaded from the server shortly after launch, or edited live).
    final settings = GetIt.I<AppSettingsController>();
    _setResolution(settings.externalResolution);
    _resolutionReactionDisposer = reaction(
      (_) => settings.externalResolution,
      (res) => unawaited(_onResolutionChanged(res)),
    );
    try {
      // getScreen() lists all screens including the primary, so an external
      // display is attached only when there's more than one. Connecting on a bare
      // non-empty list would (falsely) mark us connected with no window created,
      // and the guard in _connect would then block the real connect when a display
      // is later plugged in — leaving iOS mirroring the main screen.
      final screens = await externalDisplay.getScreen();
      if (screens.length > 1) await _connect();
    } catch (_) {
      // Platform not available (e.g. web/tests) — mirroring is simply inactive.
    }
  }

  /// Parses a `"WxH"` preference into [_width]/[_height] (null = auto).
  void _setResolution(String? value) {
    final parts = value?.toLowerCase().split('x');
    if (parts == null || parts.length != 2) {
      _width = null;
      _height = null;
      return;
    }
    _width = int.tryParse(parts[0].trim());
    _height = int.tryParse(parts[1].trim());
  }

  /// Reconnects the external display when the preferred resolution changes to a
  /// different value (the plugin picks the mode at connect time).
  Future<void> _onResolutionChanged(String? res) async {
    final oldW = _width;
    final oldH = _height;
    _setResolution(res);
    if (_width == oldW && _height == oldH) return;
    if (_connected) await _reconnect();
  }

  Future<void> _reconnect() async {
    try {
      await externalDisplay.disconnect(routeName: ExternalDisplayProtocol.routeName);
    } catch (_) {
      // Ignore — we recreate the connection below regardless.
    }
    _connected = false;
    _setReady(false);
    await _connect();
  }

  /// Push the currently-active board's render state. [widgets] should already
  /// be filtered to what is visible on the active sub-board.
  void pushActiveBoard(Board board, List<BoardWidget> widgets, List<Map<String, dynamic>> drawing) {
    _pendingClear = false;
    _pendingBoardJson = jsonEncode({
      ExternalDisplayProtocol.keyBoard: board.toJson(),
      ExternalDisplayProtocol.keyWidgets: [for (final w in widgets) w.toJson()],
      ExternalDisplayProtocol.keyDrawing: drawing,
    });
    if (_ready) unawaited(_rawSend(ExternalDisplayProtocol.actionBoard, _pendingBoardJson));
  }

  /// Tell the external screen no board is open (show the idle placeholder).
  void pushClear() {
    _pendingBoardJson = null;
    _pendingClear = true;
    if (_ready) unawaited(_rawSend(ExternalDisplayProtocol.actionClear, null));
  }

  void _onDisplayStatusChange(dynamic plugged) {
    if (plugged == true) {
      unawaited(_connect());
    } else {
      _connected = false;
      _setReady(false);
    }
  }

  Future<void> _connect() async {
    if (_connected) return;
    _connected = true;
    _setReady(false);
    try {
      await externalDisplay.connect(
        routeName: ExternalDisplayProtocol.routeName,
        width: _width,
        height: _height,
      );
      await externalDisplay.waitingTransferParametersReady(
        onReady: () {
          _setReady(true);
          _flushPending();
        },
        onError: () {
          _setReady(false);
        },
      );
      // No window was actually created (e.g. no display attached) — clear the flag
      // so a later plug-in isn't blocked by the _connected guard.
      if (!_ready) _connected = false;
    } catch (_) {
      _connected = false;
      _setReady(false);
    }
  }

  void _flushPending() {
    if (_pendingClear) {
      unawaited(_rawSend(ExternalDisplayProtocol.actionClear, null));
    } else if (_pendingBoardJson != null) {
      unawaited(_rawSend(ExternalDisplayProtocol.actionBoard, _pendingBoardJson));
    }
  }

  Future<void> _rawSend(String action, Object? value) async {
    final override = _sendOverride;
    if (override != null) {
      override(action, value);
      return;
    }
    try {
      await externalDisplay.sendParameters(action: action, value: value);
    } catch (_) {
      // A transient channel failure just drops one frame; the next push
      // (per-stroke / per-change) will re-sync the full state.
    }
  }

  void dispose() {
    if (kIsWeb) return;
    externalDisplay.removeStatusListener(_onDisplayStatusChange);
    _resolutionReactionDisposer?.call();
    // Best-effort: blank the external screen when leaving the board.
    if (_connected) unawaited(_rawSend(ExternalDisplayProtocol.actionClear, null));
  }

}
