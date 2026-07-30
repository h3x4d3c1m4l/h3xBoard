import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/services/live_share/live_share_session_service.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/share_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Opens the live-share dialog. While sharing, a viewer-count badge sits on
/// the icon so the presenter always sees they are being watched.
class ShareButton extends StatelessWidget {

  const ShareButton({super.key});

  @override
  Widget build(BuildContext context) {
    final session = GetIt.I<LiveShareSessionService>();
    final theme = FluentTheme.of(context);
    return Tooltip(
      message: context.localizations.boardTopBar_share,
      child: Observer(
        builder: (_) => IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                LucideIcons.screenShare,
                size: 20,
                color: session.isSharing ? theme.accentColor : null,
              ),
              if (session.isSharing)
                Positioned(
                  top: -6,
                  right: -8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: Text(
                        '${session.viewerCount}',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => unawaited(showShareDialog(context)),
        ),
      ),
    );
  }

}
