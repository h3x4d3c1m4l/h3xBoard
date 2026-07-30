import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/laser_pointer.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_controller.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';
import 'package:h3xboard/views/board_screen/components/buttons/laser_color_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Arms the laser pointer and offers its colours in the same tap.
///
/// The colour popup is an offer rather than a step: point at anything and it
/// gets out of the way, exactly like the pen's width popup stepping aside the
/// moment a stroke starts. Costing nothing to ignore is what makes it safe to
/// open unasked.
class LaserButton extends StatefulWidget {

  final BoardScreenController controller;
  final BoardScreenViewModel viewModel;

  const LaserButton({super.key, required this.controller, required this.viewModel});

  @override
  State<LaserButton> createState() => _LaserButtonState();

}

class _LaserButtonState extends State<LaserButton> {

  final OverlayPortalController _popupController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  // A group id of this button's own, so tapping the button doesn't register as
  // a tap *outside* the popup and close what the tap just opened.
  final Object _tapGroupId = Object();

  @override
  void initState() {
    super.initState();
    // Any laser activity — the first point, or the dot being taken away on
    // disarm — retires the popup.
    widget.controller.laser.addListener(_hidePopup);
  }

  void _hidePopup() {
    if (mounted && _popupController.isShowing) _popupController.hide();
  }

  void _onPressed() {
    final arming = !widget.viewModel.laserArmed;
    widget.controller.setLaserArmed(arming);
    if (arming) {
      _popupController.show();
    } else {
      _hidePopup();
    }
  }

  void _onColorPicked(LaserColor laserColor) {
    unawaited(widget.controller.onLaserColorPicked(laserColor));
    _hidePopup();
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = GetIt.I<AppSettingsController>();

    // Lit in the laser's own colour while armed, so the button and the dot on
    // the wall visibly belong together.
    final button = Tooltip(
      message: context.localizations.boardTopBar_laser,
      child: Observer(
        builder: (_) {
          final armed = widget.viewModel.laserArmed;
          final color = appSettings.laserColor.color;
          return IconButton(
            icon: Icon(
              LucideIcons.mousePointerClick,
              size: 20,
              color: armed ? color : null,
              shadows: armed ? [Shadow(color: color, blurRadius: 12)] : null,
            ),
            onPressed: _onPressed,
          );
        },
      ),
    );

    return OverlayPortal(
      controller: _popupController,
      // An OverlayPortal rather than a Flyout: a flyout takes a modal barrier,
      // which would swallow the very first point instead of letting it through
      // to the board and closing the popup on the way.
      overlayChildBuilder: (context) => Align(
        alignment: Alignment.topLeft,
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          offset: const Offset(0, 8),
          showWhenUnlinked: false,
          child: TapRegion(
            groupId: _tapGroupId,
            onTapOutside: (_) => _hidePopup(),
            child: _buildColorPopup(context),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: TapRegion(groupId: _tapGroupId, child: button),
      ),
    );
  }

  Widget _buildColorPopup(BuildContext context) {
    final appSettings = GetIt.I<AppSettingsController>();
    return FlyoutContent(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Observer(
        builder: (_) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(context.localizations.boardTopBar_laserColor),
            for (final laserColor in LaserColor.values)
              LaserColorButton(
                laserColor: laserColor,
                isActive: laserColor == appSettings.laserColor,
                onPressed: () => _onColorPicked(laserColor),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.laser.removeListener(_hidePopup);
    super.dispose();
  }

}
