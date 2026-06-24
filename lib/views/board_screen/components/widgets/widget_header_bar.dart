import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Header dimensions in OS pixels. board.dart multiplies these by boardPixelRatio
// to obtain the canvas-space rect (see _headerRectFor), so rendering and
// hit-testing stay in sync.
const double kHeaderWidth = 220.0;
const double kHeaderHeight = 34.0;
const double kHeaderGap = 6.0; // gap between widget bounding box and header

// Matches the selection overlay accent colour.
const Color _kAccent = Color(0xFF3B82F6);

// A persistent, always-visible chrome bar pinned above each board widget. In Use
// mode the whole bar is a drag handle (handled by the gesture layer in board.dart);
// in Arrange mode the pencil toggle becomes a blue "Done" pill. Settings/delete are
// reached via the × button and the right-click menu.
//
// The bar is screen-aligned (it does NOT rotate with the widget) and rendered at a
// constant OS-pixel size regardless of widget scale: board.dart hands it a
// pre-computed canvas-space [rect] and the content is scaled up via a FittedBox.
class WidgetHeaderBar extends StatelessWidget {

  final Rect rect;
  final String title;
  final bool isArranging;
  final VoidCallback onToggleArrange;
  final VoidCallback onClose;

  const WidgetHeaderBar({
    super.key,
    required this.rect,
    required this.title,
    required this.isArranging,
    required this.onToggleArrange,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      // Opaque so the header absorbs pointers and the drawing layer beneath it does
      // not receive strokes. The board's translucent gesture layer (above) still
      // gets the events to drive header drags, and the buttons handle their taps.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: kHeaderWidth,
            height: kHeaderHeight,
            child: _buildContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          const Icon(LucideIcons.gripVertical, size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(width: 4),
          if (isArranging)
            _DonePill(label: context.localizations.boardWidget_done, onTap: onToggleArrange)
          else
            _HeaderIconButton(
              icon: LucideIcons.pencil,
              tooltip: context.localizations.boardWidget_resizeRotate,
              onTap: onToggleArrange,
            ),
          const SizedBox(width: 2),
          _HeaderIconButton(
            icon: LucideIcons.x,
            tooltip: context.localizations.boardWidget_remove,
            hoverColor: const Color(0xFFEF4444),
            onTap: onClose,
          ),
        ],
      ),
    );
  }

}

class _HeaderIconButton extends StatefulWidget {

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? hoverColor;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();

}

class _HeaderIconButtonState extends State<_HeaderIconButton> {

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? (widget.hoverColor ?? _kAccent) : const Color(0xFF475569);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hovered ? const Color(0x0F000000) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

}

class _DonePill extends StatelessWidget {

  final String label;
  final VoidCallback onTap;

  const _DonePill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _kAccent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.check, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
