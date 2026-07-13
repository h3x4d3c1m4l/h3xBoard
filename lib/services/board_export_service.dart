import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:h3xboard/models/board_content.dart';
import 'package:h3xboard/models/board_export.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/board_screen/components/board_export_stage.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// The page a board exports to when it is written to a file: exactly 16:9 with
/// no margins, so the board is full-bleed and the PDF has no white borders.
/// Printing overrides this with the printer's own paper format.
const PdfPageFormat kBoardPdfPageFormat = PdfPageFormat(842, 473.625, marginAll: 0);

/// Encodes a captured canvas ([ui.ImageByteFormat.rawRgba] bytes) as JPEG.
/// `dart:ui` can only emit PNG and raw RGBA, so JPEG has to go through the
/// `image` package. JPEG carries no alpha channel; the board background is
/// opaque, so nothing is lost.
Uint8List encodeBoardJpeg(ByteData rgba, {required int width, required int height}) {
  final decoded = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  return img.encodeJpg(decoded, quality: 90);
}

/// Assembles one PDF page per image. With [fit] the board is centred and fitted
/// inside [pageFormat]'s margins (printing, where the paper size is the
/// printer's); without it the board is stretched to fill the page, which is
/// exact when the page is 16:9 like [kBoardPdfPageFormat] (file export).
Future<Uint8List> buildBoardPdf(
  List<Uint8List> pngPages, {
  PdfPageFormat pageFormat = kBoardPdfPageFormat,
  bool fit = false,
}) async {
  final document = pw.Document();
  for (final png in pngPages) {
    final image = pw.MemoryImage(png);
    document.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (_) => fit
          ? pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))
          : pw.Image(image, fit: pw.BoxFit.fill),
    ));
  }
  return document.save();
}

/// A finished export artifact, ready to be handed to the share sheet (or, on
/// web, to the browser's downloader).
class ExportedFile {

  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const ExportedFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

}

/// Thrown when an export cannot be produced. The caller turns it into an error
/// dialog; the message is deliberately not localized here (the service has no
/// [AppLocalizations]) — callers show their own copy.
class BoardExportException implements Exception {

  final String message;

  const BoardExportException(this.message);

  @override
  String toString() => 'BoardExportException: $message';

}

/// Renders selected sub-boards to images and delivers them as PNG/JPEG/PDF —
/// either through the platform share sheet (which on web degrades to a plain
/// file download) or to the printer.
///
/// The board is rendered *offscreen* (see [BoardExportStage]) rather than by
/// screenshotting the live editor, so sub-boards other than the active one can
/// be exported without switching tabs, and so no editor chrome leaks into the
/// output.
class BoardExportService {

  final H3xBoardFileService fileService;

  const BoardExportService({required this.fileService});

  /// Renders [request] and hands the result to the share sheet. On iPad the
  /// sheet is a popover and needs an anchor: [sharePositionOrigin] should be the
  /// global rect of whatever the user tapped.
  Future<void> share({
    required BuildContext context,
    required BoardContent content,
    required String boardTitle,
    required ExportRequest request,
    Rect? sharePositionOrigin,
  }) async {
    final files = await _buildFiles(context: context, content: content, boardTitle: boardTitle, request: request);
    await SharePlus.instance.share(ShareParams(
      files: [for (final file in files) XFile.fromData(file.bytes, mimeType: file.mimeType)],
      // XFile.fromData ignores its own `name`; the override is what actually
      // names the shared/downloaded file.
      fileNameOverrides: [for (final file in files) file.fileName],
      sharePositionOrigin: sharePositionOrigin,
    ));
  }

  /// Renders [request]'s sub-boards and opens the platform print preview with
  /// one page per sub-board. Unlike [share], the PDF is laid out against the
  /// *printer's* page format, so the board is fitted to the real paper with its
  /// margins respected rather than full-bleed on a 16:9 page.
  Future<void> print({
    required BuildContext context,
    required BoardContent content,
    required String boardTitle,
    required ExportRequest request,
  }) async {
    final pngs = await _rasterize(context: context, content: content, request: request);
    await Printing.layoutPdf(
      name: _sanitize(boardTitle),
      onLayout: (format) => buildBoardPdf(
        pngs.map((p) => p.bytes).toList(),
        pageFormat: format,
        fit: true,
      ),
    );
  }

  // Rendering

  /// Rasterises every requested sub-board to PNG bytes, in board order.
  ///
  /// Mounts [BoardExportStage] into the screen's overlay, lets it paint, grabs
  /// each page's [RepaintBoundary], and tears the stage down again. The stage is
  /// invisible, so nothing flashes on screen.
  Future<List<_Raster>> _rasterize({
    required BuildContext context,
    required BoardContent content,
    required ExportRequest request,
  }) async {
    final pages = _pagesFor(content, request.subBoardIds);
    if (pages.isEmpty) throw const BoardExportException('Nothing to export.');

    // Resolved before the first await: the context must not be used across an
    // async gap.
    final overlay = Overlay.of(context);

    // Warm the image cache first: the background image and every image widget
    // are fetched asynchronously, and a page that paints before its bytes land
    // would rasterise without them. `downloadCached` is memoized, so images the
    // editor already showed cost nothing.
    await _prewarmImages(pages);

    final entry = OverlayEntry(
      builder: (_) => BoardExportStage(pages: pages, fileService: fileService),
    );
    overlay.insert(entry);
    try {
      // One frame to build and lay the stage out, a second to let the image
      // FutureBuilders resolve and paint. A boundary that has not painted yet
      // throws from toImage.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final rasters = <_Raster>[];
      for (final page in pages) {
        final boundary = page.boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) throw const BoardExportException('The board could not be rendered.');
        final image = await boundary.toImage(pixelRatio: request.quality.pixelRatio);
        try {
          rasters.add(await _encodeRaster(image, page.board.title, request.format));
        } finally {
          image.dispose();
        }
      }
      return rasters;
    } finally {
      entry.remove();
    }
  }

  /// The sub-boards named by [subBoardIds], each paired with the widgets visible
  /// on it and its stored strokes. Kept in board order (not selection order), so
  /// a multi-page PDF reads like the tab bar.
  List<BoardExportPage> _pagesFor(BoardContent content, List<String> subBoardIds) {
    return [
      for (final board in content.subBoards)
        if (subBoardIds.contains(board.id))
          BoardExportPage(
            board: board,
            widgets: content.widgets
                .where((w) => w.isVisibleOnAllBoards || w.visibleOnBoardIds.contains(board.id))
                .toList(),
            drawing: content.drawings[board.id] ?? const [],
          ),
    ];
  }

  Future<void> _prewarmImages(List<BoardExportPage> pages) async {
    final fileIds = <String>{};
    for (final page in pages) {
      final backgroundFileId = page.board.backgroundFileId;
      if (backgroundFileId != null) fileIds.add(backgroundFileId);
      for (final bw in page.widgets) {
        final config = bw.config;
        if (config is ImageConfig && config.fileId.isNotEmpty) fileIds.add(config.fileId);
      }
    }
    // A file that fails to download is not fatal — the board renders it as its
    // fallback color / placeholder on screen too, and the export should match.
    await Future.wait(fileIds.map((id) => fileService.downloadCached(id).catchError((_) => Uint8List(0))));
  }

  // Encoding

  /// Encodes one captured canvas. PDF pages are held as PNG here and assembled
  /// into a single document later; [_Raster.bytes] is therefore always PNG for
  /// [ExportFormat.pdf].
  Future<_Raster> _encodeRaster(ui.Image image, String subBoardTitle, ExportFormat format) async {
    if (format == ExportFormat.jpeg) {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw const BoardExportException('The board could not be encoded.');
      final jpeg = encodeBoardJpeg(rgba, width: image.width, height: image.height);
      return _Raster(bytes: jpeg, subBoardTitle: subBoardTitle);
    }

    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw const BoardExportException('The board could not be encoded.');
    return _Raster(bytes: png.buffer.asUint8List(), subBoardTitle: subBoardTitle);
  }

  Future<List<ExportedFile>> _buildFiles({
    required BuildContext context,
    required BoardContent content,
    required String boardTitle,
    required ExportRequest request,
  }) async {
    final rasters = await _rasterize(context: context, content: content, request: request);
    final name = _sanitize(boardTitle);

    switch (request.format) {
      case ExportFormat.pdf:
        final pdf = await buildBoardPdf(rasters.map((r) => r.bytes).toList());
        return [ExportedFile(bytes: pdf, fileName: '$name.pdf', mimeType: 'application/pdf')];

      case ExportFormat.png:
      case ExportFormat.jpeg:
        final isPng = request.format == ExportFormat.png;
        final extension = isPng ? 'png' : 'jpg';
        final mimeType = isPng ? 'image/png' : 'image/jpeg';
        return [
          for (final raster in rasters)
            ExportedFile(
              bytes: raster.bytes,
              // One file per sub-board. A single-sub-board board exports as just
              // the board's name, with no redundant suffix.
              fileName: rasters.length == 1
                  ? '$name.$extension'
                  : '$name - ${_sanitize(raster.subBoardTitle)}.$extension',
              mimeType: mimeType,
            ),
        ];
    }
  }

  /// Makes [name] safe to use as a file name on every platform, and never empty
  /// (an empty name would produce a dotfile like `.pdf`).
  String _sanitize(String name) {
    final cleaned = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    return cleaned.isEmpty ? 'board' : cleaned;
  }

}

/// One rasterised sub-board: its encoded bytes plus the sub-board's title, which
/// becomes part of the file name when a board exports to several image files.
class _Raster {

  final Uint8List bytes;
  final String subBoardTitle;

  const _Raster({required this.bytes, required this.subBoardTitle});

}
