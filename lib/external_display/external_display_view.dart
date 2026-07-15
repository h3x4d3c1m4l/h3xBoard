import 'dart:async';
import 'dart:convert';

import 'package:external_display/transfer_parameters.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/external_display/external_display_protocol.dart';
import 'package:h3xboard/external_display/external_idle_view.dart';
import 'package:h3xboard/models/live_share/live_share_message.dart';
import 'package:h3xboard/services/board_asset_resolver.dart';
import 'package:h3xboard/views/components/board_assets.dart';
import 'package:h3xboard/views/components/live_board_view.dart';

/// The root widget rendered inside the external-display isolate. It has no
/// access to the main app's state — everything it shows arrives over the
/// plugin's [transferParameters] bus: live-share protocol frames (decoded
/// here and rendered by the shared [LiveBoardView]) and pushed asset bytes
/// (collected into a [CachedBoardAssetStore], since this isolate cannot fetch
/// files itself).
class ExternalDisplayView extends StatefulWidget {

  const ExternalDisplayView({super.key});

  @override
  State<ExternalDisplayView> createState() => _ExternalDisplayViewState();

}

class _ExternalDisplayViewState extends State<ExternalDisplayView> {

  final CachedBoardAssetStore _assets = CachedBoardAssetStore();
  final StreamController<LiveShareMessage> _messages = StreamController<LiveShareMessage>();

  @override
  void initState() {
    super.initState();
    transferParameters.addListener(_onParameters);
  }

  void _onParameters({required String action, dynamic value}) {
    if (value is! String) return;
    switch (action) {
      case ExternalDisplayProtocol.actionMessage:
        _onMessage(value);
      case ExternalDisplayProtocol.actionAsset:
        _onAsset(value);
    }
  }

  void _onMessage(String json) {
    try {
      _messages.add(LiveShareMessage.fromJson(jsonDecode(json) as Map<String, dynamic>));
    } catch (_) {
      // A malformed frame is dropped; the next snapshot re-syncs everything.
    }
  }

  void _onAsset(String json) {
    try {
      final payload = jsonDecode(json) as Map<String, dynamic>;
      final fileId = payload[ExternalDisplayProtocol.keyFileId] as String;
      final bytes = payload[ExternalDisplayProtocol.keyBytes] as String?;
      if (bytes == null) {
        _assets.fail(fileId);
      } else {
        _assets.put(fileId, base64Decode(bytes));
      }
    } catch (_) {
      // A malformed asset frame is dropped; the image keeps its placeholder.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: BoardAssets(
        resolver: _assets,
        child: LiveBoardView(
          messages: _messages.stream,
          placeholder: const ExternalIdleView(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    transferParameters.removeListener(_onParameters);
    unawaited(_messages.close());
    super.dispose();
  }

}
