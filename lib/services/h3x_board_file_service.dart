import 'dart:convert';
import 'dart:typed_data';

import 'package:chopper/chopper.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:h3xboard/services/audio/audio_stream_client.dart';
import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:h3xboard/services/credentialed_http_client_web.dart'
    if (dart.library.io) 'package:h3xboard/services/credentialed_http_client_io.dart';
import 'package:http/http.dart' show Client, MultipartFile;
import 'package:http/http.dart' as http show Request;
import 'package:http_parser/http_parser.dart';

part 'h3x_board_file_service.chopper.dart';

/// REST surface for file bytes. Browsing and deletion are metadata-only and live
/// on the WebSocket JSON-RPC API ([H3xBoardApiClient]); upload/download are REST
/// so binary streams over plain HTTP instead of base64-over-WebSocket. Both share
/// the same session cookie. See the server's `docs/file-storage.md`.
@ChopperApi()
abstract class _H3xBoardFileChopperService extends ChopperService {

  static _H3xBoardFileChopperService _create(ChopperClient client) =>
      _$_H3xBoardFileChopperService(client);

  @POST(path: '/api/v1/files')
  @multipart
  Future<Response> upload(
    @Part('path') String path,
    @PartFile('file') MultipartFile file,
  );

  // No-op response converter: the client's JsonConverter would try to JSON-decode
  // the binary stream (and reject it for the List<int> body type). Skipping it
  // leaves the raw bytes intact on `response.bodyBytes`.
  @GET(path: '/api/v1/files/{id}')
  @FactoryConverter(response: _passThroughResponse)
  Future<Response<List<int>>> download(@Path('id') String id);

  // Upserts a board's screenshot (replaces any existing one). A board has at most
  // one screenshot; the bytes ride REST just like generic uploads.
  @PUT(path: '/api/v1/boards/{boardId}/screenshot')
  @multipart
  Future<Response> uploadBoardScreenshot(
    @Path('boardId') String boardId,
    @PartFile('file') MultipartFile file,
  );

  // Downloads a board's screenshot bytes; 404 when the board has none. Same
  // pass-through as [download] so the PNG stream isn't run through JSON decoding.
  @GET(path: '/api/v1/boards/{boardId}/screenshot')
  @FactoryConverter(response: _passThroughResponse)
  Future<Response<List<int>>> downloadBoardScreenshot(@Path('boardId') String boardId);

}

/// Re-wraps the response with the raw bytes as its body so binary downloads
/// bypass JSON decoding entirely.
Response<List<int>> _passThroughResponse(Response<dynamic> response) =>
    Response<List<int>>(response.base, response.bodyBytes);

class H3xBoardFileService {

  // The underlying HTTP client is reused across base-URL changes; only the
  // Chopper client (which captures the base URL) is rebuilt in [updateBaseUrl].
  final Client _httpClient;
  _H3xBoardFileChopperService _service;

  // Chopper captures the base URL but does not expose it, and a streamed
  // download is a raw request rather than a call through the generated service.
  // The URL is therefore kept here too, updated alongside the chopper client.
  String _baseUrl;

  // Streams the response body progressively where the platform allows it. On
  // non-web this is [_httpClient] itself; on web it is a Fetch-based client,
  // because BrowserClient cannot read a body incrementally.
  late final Client _streamClient = createAudioStreamClient(_httpClient);

  // File bytes are immutable for a given id (every upload mints a fresh UUID),
  // so an in-flight/completed download can be reused across rebuilds.
  final Map<String, Future<Uint8List>> _downloadCache = {};

  H3xBoardFileService._(this._service, this._httpClient, this._baseUrl);

  static H3xBoardFileService create(String baseUrl, CookieStore cookieStore) {
    final httpClient = createCredentialedHttpClient(cookieStore);
    return H3xBoardFileService._(_buildService(baseUrl, httpClient), httpClient, baseUrl);
  }

  static _H3xBoardFileChopperService _buildService(String baseUrl, Client httpClient) {
    final chopperClient = ChopperClient(
      baseUrl: Uri.parse(baseUrl),
      client: httpClient,
      converter: JsonConverter(),
      services: [],
    );
    return _H3xBoardFileChopperService._create(chopperClient);
  }

  /// Re-points this service at [baseUrl] for all subsequent requests, dropping
  /// the download cache since cached ids belong to the previous server.
  void updateBaseUrl(String baseUrl) {
    _service = _buildService(baseUrl, _httpClient);
    _baseUrl = baseUrl;
    _downloadCache.clear();
  }

  /// Uploads [bytes] to the virtual folder [path] ("" = root) under the
  /// authenticated user, returning the new file's metadata. The server enforces
  /// the upload size limit advertised via `serverInfo().maxUploadBytes`.
  Future<FileSummary> upload({
    required List<int> bytes,
    required String fileName,
    required String contentType,
    String path = '',
  }) async {
    final part = MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
      contentType: MediaType.parse(contentType),
    );
    final response = await _service.upload(path, part);
    _requireSuccess(response);
    return FileSummary.fromJson(response.body as Map<String, dynamic>);
  }

  /// Downloads the raw bytes of the file with [id]. Throws
  /// [H3xBoardApiException] with code 404 when the file does not exist or is not
  /// owned by the caller.
  Future<Uint8List> download(String id) async {
    final response = await _service.download(id);
    _requireSuccess(response);
    return Uint8List.fromList(response.bodyBytes);
  }

  /// Like [download], but memoizes the result per [id] so repeated reads (e.g. a
  /// background image re-rendered on every rebuild) hit the network only once. A
  /// failed download is evicted so the next call retries.
  Future<Uint8List> downloadCached(String id) {
    return _downloadCache.putIfAbsent(id, () => _downloadAndCache(id));
  }

  Future<Uint8List> _downloadAndCache(String id) async {
    try {
      return await download(id);
    } catch (_) {
      // Evict the failed entry (remove() returns the stored Future, so use
      // removeWhere to avoid an unawaited-future lint) so the next call retries.
      _downloadCache.removeWhere((key, _) => key == id);
      rethrow;
    }
  }

  /// Opens the file with [id] as a progressive byte stream, for a player that
  /// wants to start a long track before the whole of it has arrived.
  ///
  /// Deliberately not cached and not routed through [downloadCached]: a stream is
  /// consumed once, and the point is to *avoid* materialising the whole file. A
  /// caller that wants the bytes kept should use [downloadCached] instead.
  ///
  /// Bypasses the generated chopper service because that one buffers the body to
  /// decode it; this issues the same request directly.
  Future<Stream<List<int>>> openDownloadStream(String id) async {
    // http.Request, not chopper's — chopper exports a Request of its own and it
    // wins the name in this file.
    final request = http.Request('GET', Uri.parse('$_baseUrl/api/v1/files/$id'));
    final response = await _streamClient.send(request);
    if (response.statusCode != 200) {
      // Nothing is going to read this body. An undrained response holds its
      // fetch reader on web, or its socket on io, until the client is closed.
      try {
        await response.stream.drain<void>();
      } on Object {
        // The connection died on its own; either way the body is gone.
      }
      throw H3xBoardApiException(code: response.statusCode, message: 'Download failed (${response.statusCode})');
    }
    return response.stream;
  }

  /// Uploads [bytes] as the screenshot for [boardId], replacing any existing one.
  /// The image is stored as a hidden `board-screenshot` file and does not bump the
  /// board's `updatedAt`. Returns the screenshot file's metadata.
  Future<FileSummary> setBoardScreenshot({
    required String boardId,
    required List<int> bytes,
  }) async {
    final part = MultipartFile.fromBytes(
      'file',
      bytes,
      filename: 'screenshot.png',
      contentType: MediaType('image', 'png'),
    );
    final response = await _service.uploadBoardScreenshot(boardId, part);
    _requireSuccess(response);
    return FileSummary.fromJson(response.body as Map<String, dynamic>);
  }

  /// Downloads the screenshot bytes for [boardId], or `null` when the board has
  /// no screenshot yet (HTTP 404). Not memoized: unlike an uploaded file, a
  /// board's screenshot is overwritten in place, so its bytes are mutable.
  Future<Uint8List?> downloadBoardScreenshot(String boardId) async {
    final response = await _service.downloadBoardScreenshot(boardId);
    if (response.statusCode == 404) return null;
    _requireSuccess(response);
    return Uint8List.fromList(response.bodyBytes);
  }

  void _requireSuccess(Response<dynamic> response) {
    if (response.isSuccessful) return;
    String message = 'Request failed (${response.statusCode})';
    try {
      final raw = response.error;
      final body = raw is String ? jsonDecode(raw) : raw;
      if (body is Map<String, dynamic>) {
        message = (body['detail'] as String?) ?? (body['title'] as String?) ?? message;
      }
    } catch (_) {}
    throw H3xBoardApiException(code: response.statusCode, message: message);
  }

}
