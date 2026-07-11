import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/views/components/flyouts/stable_flyout_controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ToolButton extends StatefulWidget {

  final IconData icon;
  final String title;
  final bool? checked;
  final WidgetBuilder? flyoutBuilder;
  final VoidCallback? onPressed;
  final Listenable? dismissSignal;

  const ToolButton({super.key, required this.icon, required this.title, this.checked, this.flyoutBuilder, this.dismissSignal, required this.onPressed});

  @override
  State<ToolButton> createState() => _ToolButtonState();

}

class _ToolButtonState extends State<ToolButton> {

  final OverlayPortalController _popupController = OverlayPortalController();
  final FlyoutController _flyoutController = StableFlyoutController();
  final FlyoutController _errorController = StableFlyoutController();
  final LayerLink _layerLink = LayerLink();
  // Unique group id per button instance so tap-outside of the popup does not
  // fire when the user taps the button itself (handled via toggle in _onPressed).
  final Object _tapGroupId = Object();

  @override
  void initState() {
    super.initState();
    widget.dismissSignal?.addListener(_onDismissSignal);
  }

  @override
  void didUpdateWidget(ToolButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dismissSignal != widget.dismissSignal) {
      oldWidget.dismissSignal?.removeListener(_onDismissSignal);
      widget.dismissSignal?.addListener(_onDismissSignal);
    }
  }

  void _onDismissSignal() {
    if (_popupController.isShowing) _popupController.hide();
  }

  @override
  Widget build(BuildContext context) {
    final buttonContent = _ToolButtonContent(icon: widget.icon, title: widget.title, hasFlyout: widget.flyoutBuilder != null);

    final button = widget.checked != null
        ? ToggleButton(checked: widget.checked!, onChanged: widget.onPressed != null ? (_) => _onPressed() : null, child: buttonContent)
        : Button(onPressed: widget.onPressed != null ? _onPressed : null, child: buttonContent);

    final baseTarget = CompositedTransformTarget(
      link: _layerLink,
      child: FlyoutTarget(
        controller: _flyoutController,
        child: FlyoutTarget(controller: _errorController, child: button),
      ),
    );

    final buttonInGroup = widget.flyoutBuilder != null
        ? TapRegion(groupId: _tapGroupId, child: baseTarget)
        : baseTarget;

    final child = Stack(
      children: [
        buttonInGroup,
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

    if (widget.flyoutBuilder == null) return child;

    // Pen/eraser set dismissSignal → non-blocking OverlayPortal so drawing can continue.
    if (widget.dismissSignal != null) {
      return OverlayPortal(
        controller: _popupController,
        overlayChildBuilder: (context) => Align(
          alignment: Alignment.topLeft,
          child: CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 16),
            showWhenUnlinked: false,
            child: TapRegion(
              groupId: _tapGroupId,
              onTapOutside: (_) => _popupController.hide(),
              child: widget.flyoutBuilder!(context),
            ),
          ),
        ),
        child: child,
      );
    }

    // Widget/settings menus use FlyoutController so MenuFlyout gets its required
    // MenuInfoProvider + Flyout ancestors (set up by showFlyout's _FlyoutPage).
    return child;
  }

  void _onPressed() {
    widget.onPressed!();
    if (widget.flyoutBuilder == null) return;

    if (widget.dismissSignal != null) {
      if (_popupController.isShowing) {
        _popupController.hide();
      } else {
        _popupController.show();
      }
    } else {
      _flyoutController.showFlyout(
        builder: widget.flyoutBuilder!,
        placementMode: FlyoutPlacementMode.bottomCenter,
        additionalOffset: 16,
      );
    }
  }

  void _onDisabledButtonPressed() {
    _errorController.showFlyout(
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
    widget.dismissSignal?.removeListener(_onDismissSignal);
    _flyoutController.dispose();
    _errorController.dispose();
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
    return Stack(
      alignment: .topRight,
      children: [
        Padding(
          padding: const .fromLTRB(4, 6, 6, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [Icon(icon, size: 18), Text(title, maxLines: 1)],
          ),
        ),
        if (hasFlyout) Padding(
          padding: const .only(top: 4),
          child: Icon(LucideIcons.chevronDown, size: 12),
        ),
      ],
    );
  }

}
