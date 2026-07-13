// What an export run produces, and at what fidelity. Plain data — no code
// generation involved (see `build.yaml`: only annotated models in `lib/models`
// are picked up by freezed/json_serializable).

enum ExportFormat { pdf, png, jpeg }

/// The board canvas is a fixed 1920×1080 logical space, so a quality level is
/// just the `pixelRatio` handed to `RenderRepaintBoundary.toImage` — the output
/// size is independent of the screen the board happens to be rendered on.
enum ExportQuality {

  low(2 / 3),
  normal(1),
  high(2);

  const ExportQuality(this.pixelRatio);

  final double pixelRatio;

  int get width => (1920 * pixelRatio).round();

  int get height => (1080 * pixelRatio).round();

}

/// One export/print job: what to render, at what quality, in which format.
/// [subBoardIds] is in board order and never empty.
class ExportRequest {

  final ExportFormat format;
  final ExportQuality quality;
  final List<String> subBoardIds;

  const ExportRequest({
    required this.format,
    required this.quality,
    required this.subBoardIds,
  });

}
