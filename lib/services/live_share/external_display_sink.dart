import 'dart:async';
import 'dart:convert';

import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/external_display_mirror.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/services/live_share/live_share_hub.dart';

/// Feeds live-share messages to the physically attached external display via
/// [ExternalDisplayMirror]'s plugin bus.
///
/// The external isolate has no network or session of its own. Alongside each
/// snapshot this sink therefore fetches the files the display needs to *draw*
/// through the authenticated file service and pushes the bytes over the bus.
/// Each id is pushed once per display connection — a fresh isolate is spawned
/// per connect.
///
/// "Needs to draw" is narrower than the snapshot's `fileIds`, and the two must
/// not be conflated. That list is the server's allowlist for anonymous viewer
/// downloads, so it has to name every referenced file — including sound-pad
/// audio. This display can never play audio (it shares the host's sound card,
/// so playing here would double the presenter rather than move it). Pushing a
/// soundboard's worth of clips it will never open would cost megabytes over the
/// plugin bus on every snapshot.
///
/// When the display (re)connects, it asks the hub for a fresh snapshot
/// instead of replaying stale retained state.
class ExternalDisplaySink implements LiveShareSink {

  final ExternalDisplayMirror _mirror;
  final H3xBoardFileService _files;
  final LiveShareHub _hub;

  final Set<String> _pushedAssetIds = {};

  ExternalDisplaySink({
    required this._mirror,
    required this._files,
    required this._hub,
  }) {
    _mirror.onReady = _onDisplayReady;
  }

  void _onDisplayReady() {
    _pushedAssetIds.clear();
    _hub.requestSnapshot();
  }

  @override
  void send(LiveShareMessage message) {
    _mirror.sendEnvelope(jsonEncode(message.toJson()));
    if (message is LiveShareSnapshot) unawaited(_pushAssets(_drawableFileIdsOf(message)));
  }

  /// The subset of a snapshot's files this display actually renders: image
  /// widgets and the board background. Derived from the widgets rather than
  /// subtracted from [LiveShareSnapshot.fileIds], so a widget type added later
  /// is silently excluded until someone decides it needs bytes here.
  List<String> _drawableFileIdsOf(LiveShareSnapshot snapshot) {
    final ids = <String>{
      for (final widget in snapshot.widgets)
        if (widget.config case ImageConfig(:final fileId) when fileId.isNotEmpty) fileId,
    };
    final background = snapshot.board.backgroundFileId;
    if (background != null) ids.add(background);
    return ids.toList();
  }

  Future<void> _pushAssets(List<String> fileIds) async {
    for (final fileId in fileIds) {
      if (!_pushedAssetIds.add(fileId)) continue;
      try {
        _mirror.sendAsset(fileId, await _files.downloadCached(fileId));
      } catch (_) {
        // Tell the display the fetch failed (it shows the error placeholder)
        // and forget the id so the next snapshot referencing it retries.
        _pushedAssetIds.remove(fileId);
        _mirror.sendAsset(fileId, null);
      }
    }
  }

}
