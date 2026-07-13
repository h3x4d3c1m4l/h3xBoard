import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/models/board_export.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/services/board_export_service.dart';
import 'package:h3xboard/views/board_screen/components/board_export_stage.dart';
import 'package:image/image.dart' as img;

Board _board(String id) => Board(
      id: id,
      title: 'Board $id',
      backgroundColor: Colors.white,
      isChalkboard: false,
      linePattern: BoardLinePattern.grid,
      lineSpacing: 64,
      lineColor: Colors.grey[100],
    );

void main() {
  // The exporter renders sub-boards the user is not looking at by painting them
  // offscreen at 1/1000 scale. This pins the two properties that makes that work:
  // the pages are painted (so their boundaries can be rasterised at all), and the
  // capture comes out at the full canvas resolution despite the tiny transform.
  testWidgets('captures every page at the requested resolution while staying invisible', (tester) async {
    final pages = [
      BoardExportPage(board: _board('a'), widgets: const [], drawing: const []),
      BoardExportPage(
        board: _board('b'),
        widgets: [
          const BoardWidget(id: 'w1', config: BoardWidgetConfig.trafficLight(), x: 960, y: 540),
        ],
        drawing: const [],
      ),
    ];

    await tester.pumpWidget(
      FluentApp(
        home: Stack(
          textDirection: TextDirection.ltr,
          children: [
            const SizedBox.expand(child: ColoredBox(color: Colors.black)),
            BoardExportStage(pages: pages),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final quality in ExportQuality.values) {
      for (final page in pages) {
        final boundary = page.boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

        // Laid out at the canonical canvas size, whatever the ancestor transform.
        expect(boundary.size, const Size(1920, 1080));

        final image = await boundary.toImage(pixelRatio: quality.pixelRatio);
        expect(image.width, quality.width);
        expect(image.height, quality.height);
        image.dispose();
      }
    }

    // Invisible: the stage occupies no space in the layout.
    expect(tester.getSize(find.byType(BoardExportStage)), Size.zero);
  });

  // The encoders run on real captured pixels, not synthetic bytes, so a wrong
  // channel count or byte order would show up here.
  testWidgets('encodes captured pages as JPEG and as a multi-page PDF', (tester) async {
    final pages = [
      BoardExportPage(board: _board('a'), widgets: const [], drawing: const []),
      BoardExportPage(board: _board('b'), widgets: const [], drawing: const []),
    ];

    await tester.pumpWidget(FluentApp(home: Stack(children: [BoardExportStage(pages: pages)])));
    await tester.pumpAndSettle();

    final pngs = <Uint8List>[];
    for (final page in pages) {
      final boundary = page.boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: ExportQuality.low.pixelRatio);

      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final jpeg = encodeBoardJpeg(rgba, width: image.width, height: image.height);
      final decodedJpeg = img.decodeJpg(jpeg)!;
      expect(decodedJpeg.width, ExportQuality.low.width);
      expect(decodedJpeg.height, ExportQuality.low.height);

      pngs.add((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      image.dispose();
    }

    final pdf = await buildBoardPdf(pngs);
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    // One page per sub-board.
    expect('/Type /Page\n'.allMatches(String.fromCharCodes(pdf)).length, 2);
  });
}
