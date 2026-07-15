import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:http/http.dart' as http;

/// Resolves the bytes of uploaded files a board references (image widgets,
/// background images) by file id.
///
/// Rendering code never talks to a concrete transport: the editor and the
/// presenter resolve through the authenticated file service, the
/// external-display isolate through bytes pushed over the plugin bus, and web
/// viewers through the anonymous share-code file endpoint. Widgets pick up
/// the right implementation from the nearest `BoardAssets` scope.
abstract class BoardAssetResolver {

  /// Resolves the bytes of the file with [fileId]. Implementations memoize per
  /// id (file bytes are immutable per id), so the returned future is stable
  /// across rebuilds and safe to hand straight to a [FutureBuilder].
  Future<Uint8List> load(String fileId);

}

/// Resolves assets through the authenticated [H3xBoardFileService] — the
/// editor and presenter path, requiring a logged-in session.
class AuthedBoardAssetResolver implements BoardAssetResolver {

  final H3xBoardFileService _files;

  const AuthedBoardAssetResolver(this._files);

  @override
  Future<Uint8List> load(String fileId) => _files.downloadCached(fileId);

}

/// An in-memory byte store fed by pushed assets. The external-display isolate
/// has no network or session of its own, so the main isolate fetches every
/// file the mirrored board references and pushes the bytes over the plugin
/// bus into this store ([put]); the isolate's widgets [load] from it.
///
/// A load may arrive before its bytes do (the snapshot renders before the
/// asset side-channel catches up) — it then waits on a completer that [put]
/// resolves. [fail] rejects waiting loads when the main isolate could not
/// fetch the file, so the image shows its error placeholder instead of
/// spinning forever; the entry is dropped so a later push can retry.
class CachedBoardAssetStore implements BoardAssetResolver {

  // Futures handed out to loaders, memoized per id so FutureBuilders receive
  // a stable object. Pending entries resolve via [_waiting] when bytes land.
  final Map<String, Future<Uint8List>> _futures = {};
  final Map<String, Completer<Uint8List>> _waiting = {};

  // Ids with resolved bytes, oldest first, so the store can evict the least
  // recently added entries and not grow unbounded across long sessions.
  final List<String> _resolved = [];

  // Generous for one board's worth of images; evicted ids re-arrive over the
  // bus with the next snapshot that references them.
  static const int _maxEntries = 32;

  @override
  Future<Uint8List> load(String fileId) {
    return _futures.putIfAbsent(fileId, () {
      final completer = Completer<Uint8List>();
      _waiting[fileId] = completer;
      return completer.future;
    });
  }

  /// Stores [bytes] for [fileId], resolving any loads already waiting on it.
  void put(String fileId, Uint8List bytes) {
    final waiting = _waiting.remove(fileId);
    if (waiting != null) {
      waiting.complete(bytes);
    } else if (!_futures.containsKey(fileId)) {
      _futures[fileId] = Future.value(bytes);
    } else {
      // Already resolved earlier — refresh eviction order below.
      _resolved.remove(fileId);
    }
    _resolved.add(fileId);
    while (_resolved.length > _maxEntries) {
      _futures.remove(_resolved.removeAt(0));
    }
  }

  /// Rejects loads waiting on [fileId] (the main isolate failed to fetch it)
  /// and forgets the entry so a later [put] can retry.
  void fail(String fileId) {
    final waiting = _waiting.remove(fileId);
    if (waiting == null) return;
    waiting.completeError(StateError('Asset $fileId could not be fetched'));
    _futures.remove(fileId);
  }

}

/// Resolves assets anonymously through the backend's share-code file endpoint
/// (`GET /api/v1/view/{code}/files/{fileId}`) — the web viewer path. The
/// server only serves files the presenter's current snapshot references, so a
/// viewer can never pull other uploads. Downloads are memoized per id;
/// failures are evicted so the next rebuild retries.
class ViewCodeBoardAssetResolver implements BoardAssetResolver {

  final String serverUrl;
  final String code;

  final http.Client _client = http.Client();
  final Map<String, Future<Uint8List>> _cache = {};

  ViewCodeBoardAssetResolver({required this.serverUrl, required this.code});

  @override
  Future<Uint8List> load(String fileId) => _cache.putIfAbsent(fileId, () => _download(fileId));

  Future<Uint8List> _download(String fileId) async {
    try {
      final response = await _client.get(Uri.parse('$serverUrl/api/v1/view/$code/files/$fileId'));
      if (response.statusCode != 200) {
        throw StateError('Asset $fileId download failed (HTTP ${response.statusCode})');
      }
      return response.bodyBytes;
    } catch (_) {
      // Evict (the value is this very future — nothing to await) so the next
      // rebuild retries instead of caching the failure.
      unawaited(_cache.remove(fileId));
      rethrow;
    }
  }

  void dispose() => _client.close();

}
