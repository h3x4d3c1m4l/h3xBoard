import 'dart:convert';
import 'dart:typed_data';

import 'package:chopper/chopper.dart';
import 'package:h3xboard/models/api/api_exception.dart';
import 'package:h3xboard/models/api/file_summary.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart' show MultipartFile;
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

}

/// Re-wraps the response with the raw bytes as its body so binary downloads
/// bypass JSON decoding entirely.
Response<List<int>> _passThroughResponse(Response<dynamic> response) =>
    Response<List<int>>(response.base, response.bodyBytes);

class H3xBoardFileService {

  final _H3xBoardFileChopperService _service;

  // File bytes are immutable for a given id (every upload mints a fresh UUID),
  // so an in-flight/completed download can be reused across rebuilds.
  final Map<String, Future<Uint8List>> _downloadCache = {};

  H3xBoardFileService._(this._service);

  static H3xBoardFileService create(String baseUrl) {
    final httpClient = BrowserClient()..withCredentials = true;
    final chopperClient = ChopperClient(
      baseUrl: Uri.parse(baseUrl),
      client: httpClient,
      converter: JsonConverter(),
      services: [],
    );
    return H3xBoardFileService._(_H3xBoardFileChopperService._create(chopperClient));
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
