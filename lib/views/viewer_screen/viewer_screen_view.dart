import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/services/live_share/live_view_client.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/components/board_assets.dart';
import 'package:h3xboard/views/components/dialogs/watch_code_dialog.dart';
import 'package:h3xboard/views/components/live_board_view.dart';
import 'package:h3xboard/views/viewer_screen/viewer_screen_controller.dart';
import 'package:h3xboard/views/viewer_screen/viewer_screen_view_model.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ViewerScreenView extends ScreenViewBase<ViewerScreenViewModel, ViewerScreenController> {

  const ViewerScreenView({
    required super.viewModel,
    required super.controller,
    required super.contextAccessor,
  });

  @override
  Widget get body {
    final client = controller.client;
    return client == null ? _CodeEntryPrompt(controller: controller) : _buildViewer(client);
  }

  /// The live mirror: the shared board full-bleed, with session-lifecycle
  /// overlays (connecting spinner, paused/reconnecting banner, terminal
  /// panels) driven by the client's state.
  Widget _buildViewer(LiveViewClient client) {
    return Stack(
      children: [
        Positioned.fill(
          child: BoardAssets(
            resolver: controller.assetResolver!,
            child: LiveBoardView(
              messages: client.messages,
              // Connected, but nothing is being presented — the web analogue of
              // the external display's idle placeholder.
              placeholder: _PlaceholderView(
                icon: LucideIcons.monitor,
                title: localizations.viewerScreen_waiting_title,
                message: localizations.viewerScreen_waiting_message,
              ),
              onGapDetected: controller.onGapDetected,
              onUnsupportedContentChanged: controller.onUnsupportedContentChanged,
            ),
          ),
        ),
        Positioned.fill(
          child: ValueListenableBuilder<LiveViewState>(
            valueListenable: client.state,
            builder: (context, state, _) => switch (state) {
              LiveViewState.connecting => const ColoredBox(
                  color: Color(0xFFF3F3F3),
                  child: Center(child: ProgressRing()),
                ),
              LiveViewState.reconnecting => _StatusBanner(message: localizations.viewerScreen_reconnecting),
              LiveViewState.paused => _StatusBanner(message: localizations.viewerScreen_paused),
              LiveViewState.ended => _TerminalPanel(
                  icon: LucideIcons.circleStop,
                  title: localizations.viewerScreen_ended_title,
                  message: localizations.viewerScreen_ended_message,
                  controller: controller,
                ),
              LiveViewState.notFound => _TerminalPanel(
                  icon: LucideIcons.searchX,
                  title: localizations.viewerScreen_notFound_title,
                  message: localizations.viewerScreen_notFound_message,
                  controller: controller,
                ),
              LiveViewState.full => _TerminalPanel(
                  icon: LucideIcons.users,
                  title: localizations.viewerScreen_full_title,
                  message: localizations.viewerScreen_full_message,
                  controller: controller,
                ),
              // Nothing on screen can be trusted while frames are unreadable, so
              // this takes the panel rather than a banner. It clears itself if the
              // presenter moves to a board this build does understand.
              LiveViewState.unsupported => _TerminalPanel(
                  icon: LucideIcons.triangleAlert,
                  title: localizations.viewerScreen_unsupported_title,
                  message: localizations.viewerScreen_unsupported_message,
                  controller: controller,
                ),
              // A board that renders with pieces missing says so from here, where
              // it can't collide with the banners the states above own.
              LiveViewState.live || LiveViewState.waiting => ValueListenableBuilder<bool>(
                  valueListenable: controller.hasUnsupportedWidgets,
                  builder: (context, hasUnsupported, _) => hasUnsupported
                      ? _StatusBanner(message: localizations.viewerScreen_unsupportedWidgets)
                      : const SizedBox.shrink(),
                ),
            },
          ),
        ),
        // Discreet leave button; the terminal panels have their own buttons
        // but keeping this always visible gives one consistent way out.
        Positioned(
          top: 12,
          right: 12,
          child: Tooltip(
            message: localizations.viewerScreen_leave,
            child: IconButton(
              icon: const Icon(LucideIcons.x, size: 20),
              onPressed: controller.onLeave,
            ),
          ),
        ),
      ],
    );
  }

}

/// The "no code yet" face of the viewer (`/view`, and "enter another code"):
/// the idle placeholder with the code popup opened over it.
///
/// The popup *is* this page — there is nothing to do here without it — so it
/// opens on the first frame and dismissing it leaves the viewer altogether
/// rather than stranding the user on an empty screen.
class _CodeEntryPrompt extends StatefulWidget {

  final ViewerScreenController controller;

  const _CodeEntryPrompt({required this.controller});

  @override
  State<_CodeEntryPrompt> createState() => _CodeEntryPromptState();

}

class _CodeEntryPromptState extends State<_CodeEntryPrompt> {

  @override
  void initState() {
    super.initState();
    // A dialog needs a navigator-attached context, which this one only has once
    // the page it belongs to is in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_promptForCode()));
  }

  Future<void> _promptForCode() async {
    if (!mounted) return;
    final code = await showWatchCodeDialog(context);
    if (!mounted) return;
    if (code == null) {
      widget.controller.onLeave();
    } else {
      widget.controller.onCodeEntered(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PlaceholderView(
      icon: LucideIcons.monitor,
      title: context.localizations.viewerScreen_title,
      message: context.localizations.viewerScreen_codeDescription,
    );
  }

}

/// The viewer's calm full-screen placeholder: a large glyph over a title and a
/// line of explanation, gray on the same light background the external display
/// uses when it has nothing to show.
class _PlaceholderView extends StatelessWidget {

  final IconData icon;
  final String title;
  final String message;

  const _PlaceholderView({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final gray = Colors.grey[120];
    return ColoredBox(
      color: const Color(0xFFF3F3F3),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 24,
            children: [
              Icon(icon, size: 128, color: gray),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: gray),
              ),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: gray),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// A non-blocking banner over the board for transient states.
class _StatusBanner extends StatelessWidget {

  final String message;

  const _StatusBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: InfoBar(
            title: Text(message),
            severity: InfoBarSeverity.warning,
          ),
        ),
      ),
    );
  }

}

/// Full-screen panel for terminal states (session ended / code not found).
class _TerminalPanel extends StatelessWidget {

  final IconData icon;
  final String title;
  final String message;
  final ViewerScreenController controller;

  const _TerminalPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final gray = Colors.grey[120];
    return ColoredBox(
      color: const Color(0xFFF3F3F3),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Icon(icon, size: 96, color: gray),
              Text(title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: gray)),
              Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: gray)),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: controller.onWatchAnother,
                    child: Text(context.localizations.viewerScreen_watchAnother),
                  ),
                  Button(
                    onPressed: controller.onLeave,
                    child: Text(context.localizations.viewerScreen_leave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
