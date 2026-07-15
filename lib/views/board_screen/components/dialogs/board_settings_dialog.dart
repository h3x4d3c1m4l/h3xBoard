import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/background_lines.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/board_background_image.dart';
import 'package:h3xboard/views/board_screen/components/backgrounds/chalkboard_background.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/color_picker_dialog.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/file_picker_dialog.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/themable_panel_dialog.dart';
import 'package:h3xboard/views/components/flyouts/app_menu_flyout.dart';
import 'package:h3xboard/views/components/flyouts/continuous_menu_flyout.dart';
import 'package:h3xboard/views/components/flyouts/stable_flyout_controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:scroll_edge_hint/scroll_edge_hint.dart';

// The board-color presets, mirroring the previous settings flyout: two plain
// colors and two chalkboard tints.
const List<Color> _regularBoardColors = [Colors.black, Colors.white];
const List<Color> _chalkboardColors = [Color(0xFF1F3A2E), Color(0xFF2B2F3A)];

// The line-color presets, mirroring the previous settings flyout.
final List<Color> _lineColorPresets = [Colors.black, Colors.white, Colors.grey[100], Colors.errorPrimaryColor];

// Grid-spacing slider bounds, matching the previous flyout.
const double _minSpacing = 32;
const double _maxSpacing = 128;

/// The appearance fields a board-settings edit can produce. Returned by the
/// dialog so the caller can apply it as a single change.
typedef BoardAppearance = Board;

/// Edits a copy of [board]'s appearance with a live preview. Nothing is applied
/// until the user confirms: the dialog pops the edited [Board] on **Done** (or
/// when a board is chosen from **Copy from…**), or `null` when dismissed.
class BoardSettingsDialog extends StatefulWidget {

  /// The board whose appearance is being edited (the working copy is seeded from
  /// it and its id/title are preserved on the result).
  final Board board;

  /// The other sub-boards, offered in the "Copy from…" menu.
  final List<Board> otherBoards;

  final H3xBoardApiClient apiClient;
  final H3xBoardFileService fileService;

  /// The board's canvas-to-display ratio (1920×1080 canvas px per on-screen px),
  /// so the preview can render grid squares at the same on-screen size as the
  /// real board behind the dialog.
  final double boardPixelRatio;

  const BoardSettingsDialog({
    super.key,
    required this.board,
    required this.otherBoards,
    required this.apiClient,
    required this.fileService,
    required this.boardPixelRatio,
  });

  @override
  State<BoardSettingsDialog> createState() => _BoardSettingsDialogState();

}

class _BoardSettingsDialogState extends State<BoardSettingsDialog> {

  final FlyoutController _copyFromController = StableFlyoutController();

  late Board _draft = widget.board;

  void _update(Board Function(Board) change) => setState(() => _draft = change(_draft));

  bool get _hasBackgroundImage => _draft.backgroundFileId != null;

  // --- Board color ---------------------------------------------------------

  bool _isColorActive(Color color, {required bool isChalkboard}) =>
      !_hasBackgroundImage && _draft.backgroundColor == color && _draft.isChalkboard == isChalkboard;

  bool get _isCustomColorActive {
    if (_hasBackgroundImage || _draft.isChalkboard) return false;
    return !_regularBoardColors.contains(_draft.backgroundColor);
  }

  void _pickColor(Color color, {required bool isChalkboard}) =>
      _update((b) => b.copyWith(backgroundColor: color, isChalkboard: isChalkboard, backgroundFileId: null));

  Future<void> _pickCustomColor() async {
    final picked = await showColorPicker(context, initial: _draft.backgroundColor);
    if (picked == null) return;
    _pickColor(picked, isChalkboard: false);
  }

  // --- Background image ----------------------------------------------------

  Future<void> _chooseBackgroundImage() async {
    final result = await showDialog<FilePickerResult>(
      context: context,
      builder: (_) => FilePickerDialog(
        apiClient: widget.apiClient,
        fileService: widget.fileService,
        initialFolder: backgroundsFolder,
        currentFileId: _draft.backgroundFileId,
        title: context.localizations.backgroundPicker_title,
        allowRemove: true,
      ),
    );
    if (result == null) return;
    _update((b) => b.copyWith(backgroundFileId: result.fileId));
  }

  // --- Board lines ---------------------------------------------------------

  void _pickLinePattern(BoardLinePattern pattern) => _update((b) => b.copyWith(linePattern: pattern));

  void _pickLineColor(Color color) => _update((b) => b.copyWith(lineColor: color));

  bool get _isCustomLineColorActive => !_lineColorPresets.contains(_draft.lineColor);

  Future<void> _pickCustomLineColor() async {
    final picked = await showColorPicker(context, initial: _draft.lineColor);
    if (picked == null) return;
    _pickLineColor(picked);
  }

  // --- Footer actions ------------------------------------------------------

  void _resetToDefault() => _update((b) => b.copyWith(
        backgroundColor: Colors.white,
        isChalkboard: false,
        linePattern: BoardLinePattern.none,
        lineSpacing: 64,
        lineColor: Colors.grey[100],
        backgroundFileId: null,
      ));

  void _cancel() => Navigator.of(context).pop();

  void _confirm() => Navigator.of(context).pop(_draft);

  // Copies [source]'s appearance onto the current board (keeping its id/title)
  // and closes, committing the change immediately.
  void _copyFrom(Board source) {
    Navigator.of(context).pop(_draft.copyWith(
      backgroundColor: source.backgroundColor,
      isChalkboard: source.isChalkboard,
      linePattern: source.linePattern,
      lineSpacing: source.lineSpacing,
      lineColor: source.lineColor,
      backgroundFileId: source.backgroundFileId,
    ));
  }

  void _openCopyFromMenu() {
    _copyFromController.showFlyout(
      builder: (ctx) => AppMenuFlyout(
        shape: continuousMenuShape(ctx),
        itemMargin: kMenuItemMargin,
        items: [
          for (final board in widget.otherBoards)
            MenuFlyoutItem(
              text: Text(board.title),
              onPressed: () {
                Navigator.of(ctx).pop();
                _copyFrom(board);
              },
            ),
        ],
      ),
      placementMode: FlyoutPlacementMode.topCenter,
      additionalOffset: 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return ThemablePanelDialog(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 880),
      content: SizedBox(
        width: 640,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                title: loc.boardSettingsDialog_title,
                subtitle: loc.boardSettingsDialog_subtitle,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              Flexible(
                // Edge fades make it obvious there are more options to scroll to;
                // backgroundColor matches the white panel dialog surface.
                child: ScrollEdgeHint.builder(
                  backgroundColor: Colors.white,
                  extent: 24,
                  builder: (context, controller) => Scrollbar(
                    controller: controller,
                    // Nudge the thumb closer to the dialog edge.
                    style: const ScrollbarThemeData(
                      padding: EdgeInsetsDirectional.only(end: 1, top: 4, bottom: 4),
                    ),
                    // Suppress the platform/default scrollbar (notably on web) so it
                    // doesn't double up with this fluent one.
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        controller: controller,
                        // Gutter so content clears the scrollbar sitting at the edge.
                        padding: const EdgeInsets.only(right: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PreviewPanel(
                            board: _draft,
                            fileService: widget.fileService,
                            boardPixelRatio: widget.boardPixelRatio,
                            label: loc.boardSettingsDialog_livePreview,
                          ),
                            const SizedBox(height: 24),
                            _buildBoardColorSection(loc),
                            const SizedBox(height: 24),
                            _buildBackgroundImageSection(loc),
                            const SizedBox(height: 24),
                            _buildBoardLinesSection(loc),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      leftActions: [
        OutlinedButton(
          onPressed: _resetToDefault,
          child: Text(loc.boardSettingsDialog_resetToDefault),
        ),
        FlyoutTarget(
          controller: _copyFromController,
          child: OutlinedButton(
            onPressed: widget.otherBoards.isEmpty ? null : _openCopyFromMenu,
            child: Text(loc.boardSettingsDialog_copyFrom),
          ),
        ),
      ],
      rightActions: [
        Button(
          onPressed: _cancel,
          child: Text(loc.boardSettingsDialog_cancel),
        ),
        FilledButton(
          onPressed: _confirm,
          child: Text(loc.boardSettingsDialog_ok),
        ),
      ],
    );
  }

  Widget _buildBoardColorSection(AppLocalizations loc) {
    return _Section(
      icon: LucideIcons.paintBucket,
      title: loc.boardSettingsDialog_boardColor,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final color in _regularBoardColors)
            _ColorSwatch(
              color: color,
              isActive: _isColorActive(color, isChalkboard: false),
              onPressed: () => _pickColor(color, isChalkboard: false),
            ),
          for (final color in _chalkboardColors)
            _ColorSwatch(
              color: color,
              isChalkboard: true,
              isActive: _isColorActive(color, isChalkboard: true),
              onPressed: () => _pickColor(color, isChalkboard: true),
            ),
          const _SwatchDivider(),
          _CustomColorSwatch(
            color: _isCustomColorActive ? _draft.backgroundColor : null,
            isActive: _isCustomColorActive,
            tooltip: loc.boardSettingsDialog_customColor,
            onPressed: _pickCustomColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundImageSection(AppLocalizations loc) {
    return _Section(
      icon: LucideIcons.image,
      title: loc.boardSettingsDialog_backgroundImage,
      subtitle: _hasBackgroundImage ? loc.boardSettingsDialog_backgroundSelected : loc.boardSettingsDialog_backgroundNone,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasBackgroundImage) ...[
            Tooltip(
              message: loc.filePicker_remove,
              child: IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () => _update((b) => b.copyWith(backgroundFileId: null)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Button(
            onPressed: _chooseBackgroundImage,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.upload, size: 16),
                const SizedBox(width: 8),
                Text(loc.boardSettingsDialog_chooseImage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardLinesSection(AppLocalizations loc) {
    final linesEnabled = _draft.linePattern != BoardLinePattern.none;
    return _Section(
      icon: LucideIcons.grid2x2,
      title: loc.boardSettingsDialog_boardLines,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _PatternTile(
                  icon: LucideIcons.square,
                  label: loc.boardSettingsDialog_lineNone,
                  isActive: _draft.linePattern == BoardLinePattern.none,
                  onPressed: () => _pickLinePattern(BoardLinePattern.none),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PatternTile(
                  icon: LucideIcons.rows3,
                  label: loc.boardSettingsDialog_lineLines,
                  isActive: _draft.linePattern == BoardLinePattern.horizontal,
                  onPressed: () => _pickLinePattern(BoardLinePattern.horizontal),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PatternTile(
                  icon: LucideIcons.grid2x2,
                  label: loc.boardSettingsDialog_lineGrid,
                  isActive: _draft.linePattern == BoardLinePattern.grid,
                  onPressed: () => _pickLinePattern(BoardLinePattern.grid),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PatternTile(
                  icon: LucideIcons.grip,
                  label: loc.boardSettingsDialog_lineDots,
                  isActive: _draft.linePattern == BoardLinePattern.dots,
                  onPressed: () => _pickLinePattern(BoardLinePattern.dots),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                loc.boardSettingsDialog_spacing.toUpperCase(),
                style: FluentTheme.of(context).typography.caption,
              ),
              const Spacer(),
              Text(
                loc.boardSettingsDialog_spacingValue(_draft.lineSpacing.round()),
                style: FluentTheme.of(context).typography.caption?.copyWith(color: FluentTheme.of(context).accentColor),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(LucideIcons.grid3x3, size: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Slider(
                    min: _minSpacing,
                    max: _maxSpacing,
                    value: _draft.lineSpacing.clamp(_minSpacing, _maxSpacing),
                    onChanged: linesEnabled ? (v) => _update((b) => b.copyWith(lineSpacing: v)) : null,
                  ),
                ),
              ),
              const Icon(LucideIcons.grid2x2, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            loc.boardSettingsDialog_lineColor.toUpperCase(),
            style: FluentTheme.of(context).typography.caption,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final color in _lineColorPresets)
                _ColorSwatch(
                  color: color,
                  isActive: _draft.lineColor == color,
                  onPressed: () => _pickLineColor(color),
                ),
              const _SwatchDivider(),
              _CustomColorSwatch(
                color: _isCustomLineColorActive ? _draft.lineColor : null,
                isActive: _isCustomLineColorActive,
                tooltip: loc.boardSettingsDialog_customColor,
                onPressed: _pickCustomLineColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _copyFromController.dispose();
    super.dispose();
  }

}

/// The dialog header: title + subtitle on the left, a close button on the right.
class _Header extends StatelessWidget {

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const _Header({required this.title, required this.subtitle, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.typography.subtitle),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.typography.body?.copyWith(color: theme.resources.textFillColorSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.x, size: 18),
          onPressed: onClose,
        ),
      ],
    );
  }

}

/// A labelled settings section: an accent-tinted icon + title, with either an
/// inline [trailing] control (one-liners like the background row) or a [child]
/// laid out below the heading.
class _Section extends StatelessWidget {

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;

  const _Section({required this.icon, required this.title, this.subtitle, this.trailing, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: theme.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.typography.bodyStrong),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.typography.caption?.copyWith(color: theme.resources.textFillColorSecondary),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        if (child != null) ...[
          const SizedBox(height: 16),
          child!,
        ],
      ],
    );
  }

}

/// A live preview of the board's appearance, rendered from [board] exactly as
/// the real board paints it (color/chalkboard/image + line overlay), with a
/// sample stroke drawn on top and a "Live preview" badge.
class _PreviewPanel extends StatelessWidget {

  final Board board;
  final H3xBoardFileService fileService;
  final double boardPixelRatio;
  final String label;

  const _PreviewPanel({
    required this.board,
    required this.fileService,
    required this.boardPixelRatio,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    // Render the grid at the board's on-screen scale (not the full canvas) so a
    // square in the preview is the same size as a square on the real board; the
    // preview band then just shows a small slice of it.
    Widget box = BackgroundLines(
      pattern: board.linePattern,
      spacing: board.lineSpacing / boardPixelRatio,
      color: board.lineColor,
      child: const SizedBox.expand(),
    );
    final fileId = board.backgroundFileId;
    final Widget background;
    if (fileId != null) {
      background = BoardBackgroundImage(
        fileId: fileId,
        fallbackColor: board.backgroundColor,
        child: box,
      );
    } else if (board.isChalkboard) {
      background = ChalkboardBackground(boardColor: board.backgroundColor, child: box);
    } else {
      background = ColoredBox(color: board.backgroundColor, child: box);
    }

    // The sample stroke must contrast with the board: a white squiggle on a white
    // board reads as an empty/broken preview. Over an image we can't know the
    // brightness, so default to white (matches drawing over photos).
    final strokeColor = fileId != null
        ? Colors.white
        : (board.backgroundColor.computeLuminance() > 0.5 ? const Color(0xFF1F2937) : Colors.white);

    final theme = FluentTheme.of(context);
    return Container(
      // A defined border so the preview stays visible when the board color
      // matches the (white) dialog surface.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.resources.controlStrokeColorSecondary, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      // Half-height banner showing a 1:1 slice of the board (the background fills
      // the band at native scale and is clipped, rather than fitting the whole canvas).
      child: AspectRatio(
        aspectRatio: 32 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: background),
            Positioned.fill(child: CustomPaint(painter: _PreviewStrokePainter(color: strokeColor))),
            Positioned(
              top: 12,
              left: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.eye, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(label, style: theme.typography.caption?.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Paints a single sine-wave stroke across the 1920×1080 canvas in [color], the
/// sample squiggle shown in the preview.
class _PreviewStrokePainter extends CustomPainter {

  final Color color;

  const _PreviewStrokePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final midY = size.height / 2;
    final amplitude = size.height * 0.18;
    final startX = size.width * 0.18;
    final endX = size.width * 0.82;
    path.moveTo(startX, midY);
    for (double x = startX; x <= endX; x += 8) {
      final t = (x - startX) / (endX - startX);
      final y = midY - math.sin(t * math.pi * 2) * amplitude;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PreviewStrokePainter oldDelegate) => oldDelegate.color != color;

}

/// One large pattern-choice tile (None / Lines / Grid).
class _PatternTile extends StatelessWidget {

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _PatternTile({required this.icon, required this.label, required this.isActive, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        final highlight = isActive || states.isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive ? theme.accentColor.withValues(alpha: 0.1) : theme.resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: highlight ? theme.accentColor : theme.resources.controlStrokeColorDefault,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: isActive ? theme.accentColor : null),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.typography.body?.copyWith(
                  color: isActive ? theme.accentColor : null,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

/// A preset color swatch with a selection ring + check badge. Renders a pen
/// glyph for chalkboard tints, mirroring the old preset buttons.
class _ColorSwatch extends StatelessWidget {

  final Color color;
  final bool isActive;
  final bool isChalkboard;
  final VoidCallback onPressed;

  const _ColorSwatch({
    required this.color,
    required this.isActive,
    required this.onPressed,
    this.isChalkboard = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    // Pick a check/glyph color that stays legible on the swatch.
    final onColor = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? theme.accentColor : theme.resources.controlStrokeColorDefault,
            width: isActive ? 3 : 1,
          ),
        ),
        child: isActive
            ? Icon(LucideIcons.check, size: 18, color: onColor)
            : (isChalkboard ? Icon(LucideIcons.pen, size: 16, color: onColor) : null),
      ),
    );
  }

}

/// The custom-color button: a palette (board color) or plus (line color) glyph
/// when no custom color is set; once a custom color is chosen it shows that
/// color with a selection ring, like a preset swatch.
class _CustomColorSwatch extends StatelessWidget {

  final Color? color;
  final bool isActive;
  final String tooltip;
  final VoidCallback onPressed;

  const _CustomColorSwatch({
    required this.color,
    required this.isActive,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final showColor = isActive && color != null;
    final onColor = (color ?? Colors.white).computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: showColor ? color : theme.resources.cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? theme.accentColor : theme.resources.controlStrokeColorDefault,
              width: isActive ? 3 : 1,
            ),
          ),
          child: Icon(
            showColor ? LucideIcons.check : LucideIcons.palette,
            size: 18,
            color: showColor ? onColor : theme.resources.textFillColorSecondary,
          ),
        ),
      ),
    );
  }

}

/// A thin vertical rule separating the presets from the custom-color button.
class _SwatchDivider extends StatelessWidget {

  const _SwatchDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: FluentTheme.of(context).resources.controlStrokeColorDefault,
    );
  }

}
