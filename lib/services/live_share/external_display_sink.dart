import 'dart:async';
import 'dart:convert';

import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/external_display_mirror.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/services/live_share/live_share_hub.dart';

/// Feeds live-share messages to the physically attached external display via
/// [ExternalDisplayMirror]'s plugin bus.
///
/// The external isolate has no network or session of its own, so alongside
/// each snapshot this sink fetches every referenced file through the
/// authenticated file service and pushes the bytes over the bus (each id
/// once per display connection — a fresh isolate is spawned per connect).
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
    if (message is LiveShareSnapshot) unawaited(_pushAssets(message.fileIds));
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
