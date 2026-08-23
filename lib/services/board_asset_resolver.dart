import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:h3xboard/services/audio/audio_stream_client.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:http/http.dart';

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

  /// Opens [fileId] as a progressive byte stream, or returns null when this
  /// resolver has no way to produce one.
  ///
  /// Only the audio player uses this, and only to start a long track before it
  /// has fully arrived. Null is a perfectly ordinary answer: the
  /// external-display store is handed whole files over the plugin bus and has
  /// nothing to stream from. Every caller must therefore be able to fall back
  /// to [load]. Deliberately **not** memoized: unlike [load] this is consumed
  /// once, and holding a spent stream would hand the second caller a dead one.
  Future<Stream<List<int>>>? openStream(String fileId) => null;

}

/// Resolves assets through the authenticated [H3xBoardFileService] — the
/// editor and presenter path, requiring a logged-in session.
class AuthedBoardAssetResolver implements BoardAssetResolver {

  final H3xBoardFileService _files;

  const AuthedBoardAssetResolver(this._files);

  @override
  Future<Uint8List> load(String fileId) => _files.downloadCached(fileId);

  @override
  Future<Stream<List<int>>>? openStream(String fileId) => _files.openDownloadStream(fileId);

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

  /// Always null: this store is *given* whole files over the plugin bus and has
  /// no transport of its own to read progressively from. The external display
  /// never plays audio anyway — it shares the host's output device — so nothing
  /// asks. A caller that did ask would fall back to [load].
  @override
  Future<Stream<List<int>>>? openStream(String fileId) => null;

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

  final Client _client = Client();
  final Map<String, Future<Uint8List>> _cache = {};

  // Separate from [_client] because only this one is guaranteed to read the
  // body progressively — see createAudioStreamClient.
  final Client _streamClient = createAudioStreamClient(Client());

  ViewCodeBoardAssetResolver({required this.serverUrl, required this.code});

  @override
  Future<Uint8List> load(String fileId) => _cache.putIfAbsent(fileId, () => _download(fileId));

  @override
  Future<Stream<List<int>>>? openStream(String fileId) async {
    final request = Request('GET', Uri.parse('$serverUrl/api/v1/view/$code/files/$fileId'));
    final response = await _streamClient.send(request);
    if (response.statusCode != 200) {
      // Nothing is going to read this body. An undrained response holds its
      // fetch reader on web, or its socket on io, until the client is closed.
      try {
        await response.stream.drain<void>();
      } on Object {
        // The connection died on its own; either way the body is gone.
      }
      throw StateError('Asset $fileId stream failed (HTTP ${response.statusCode})');
    }
    return response.stream;
  }

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

  void dispose() {
    _client.close();
    _streamClient.close();
  }

}
