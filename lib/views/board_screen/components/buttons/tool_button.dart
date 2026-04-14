import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ToolButton extends StatefulWidget {

  final IconData icon;
  final String title;
  final bool? checked;
  final WidgetBuilder? flyoutBuilder;
  final VoidCallback? onPressed;

  const ToolButton({super.key, required this.icon, required this.title, this.checked, this.flyoutBuilder, required this.onPressed});

  @override
  State<ToolButton> createState() => _ToolButtonState();

}

class _ToolButtonState extends State<ToolButton> {

  final FlyoutController _controller = FlyoutController();

  @override
  Widget build(BuildContext context) {
    Widget buttonContent = _ToolButtonContent(icon: widget.icon, title: widget.title, hasFlyout: widget.flyoutBuilder != null);

    Widget button;
    if (widget.checked != null) {
      button = ToggleButton(
        checked: widget.checked!,
        onChanged: widget.onPressed != null ? (_) => _onPressed() : null,
        child: buttonContent,
      );
    } else {
      button = Button(onPressed: widget.onPressed != null ? _onPressed : null, child: buttonContent);
    }

    return Stack(
      children: [
        FlyoutTarget(
          controller: _controller,
          child: button,
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onPressed == null ? _onDisabledButtonPressed : null,
          child: Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: button,
          ),
        ),
      ],
    );
  }

  void _onPressed() {
    widget.onPressed!();
    if (widget.flyoutBuilder != null) {
      _controller.showFlyout(
        builder: widget.flyoutBuilder!,
        placementMode: FlyoutPlacementMode.bottomCenter,
        additionalOffset: 16,
      );
    }
    }

  void _onDisabledButtonPressed() {
    _controller.showFlyout(
      builder: (context) => FlyoutContent(child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(LucideIcons.circleAlert, color: Colors.errorPrimaryColor),
          Text(context.localizations.toolButton_actionNotAvailable),
        ],
      )),
      placementMode: FlyoutPlacementMode.bottomCenter,
      additionalOffset: 16,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

}

class _ToolButtonContent extends StatelessWidget {

  final IconData icon;
  final String title;
  final bool hasFlyout;

  const _ToolButtonContent({required this.icon, required this.title, this.hasFlyout = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: hasFlyout ? const EdgeInsets.fromLTRB(8, 8, 0, 8) : const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [Icon(icon), Text(title, maxLines: 1)],
          ),
          if (hasFlyout) Icon(LucideIcons.chevronDown),
        ],
      ),
    );
  }

}
