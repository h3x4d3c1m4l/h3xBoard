import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/services/live_share/live_view_client.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/components/board_assets.dart';
import 'package:h3xboard/views/components/continuous_text_box.dart';
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
    return client == null ? _buildCodeEntry() : _buildViewer(client);
  }

  /// The "enter a code" form, styled like the login screen.
  Widget _buildCodeEntry() {
    return ScaffoldPage(
      content: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(
                localizations.viewerScreen_title,
                style: FluentTheme.of(context).typography.title,
                textAlign: TextAlign.center,
              ),
              Text(
                localizations.viewerScreen_codeDescription,
                textAlign: TextAlign.center,
              ),
              ContinuousTextBox(
                controller: viewModel.codeController,
                placeholder: localizations.viewerScreen_codePlaceholder,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => controller.onSubmitCode(),
              ),
              FilledButton(
                onPressed: controller.onSubmitCode,
                child: Text(localizations.viewerScreen_watch),
              ),
              Button(
                onPressed: controller.onLeave,
                child: Text(localizations.viewerScreen_back, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
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
              placeholder: _WaitingView(),
              onGapDetected: controller.onGapDetected,
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
              LiveViewState.live || LiveViewState.waiting => const SizedBox.shrink(),
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

/// Shown while connected but nothing is being presented — the web analogue of
/// the external display's idle placeholder.
class _WaitingView extends StatelessWidget {

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
              Icon(LucideIcons.monitor, size: 128, color: gray),
              Text(
                context.localizations.viewerScreen_waiting_title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: gray),
              ),
              Text(
                context.localizations.viewerScreen_waiting_message,
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
