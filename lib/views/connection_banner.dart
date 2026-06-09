import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';

/// Overlays a subtle, non-blocking "Reconnecting…" bar at the top of the app
/// whenever the WebSocket is silently retrying after a transient drop. It never
/// intercepts input, so the user can keep working without losing any data.
class ConnectionBanner extends StatelessWidget {

  final Widget child;

  const ConnectionBanner({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final client = GetIt.I<H3xBoardApiClient>();
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<H3xConnectionState>(
            valueListenable: client.connectionState,
            builder: (context, state, _) {
              if (state != H3xConnectionState.reconnecting) {
                return const SizedBox.shrink();
              }
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IgnorePointer(
                    child: InfoBar(
                      title: Text(context.localizations.connectionBanner_reconnecting),
                      severity: InfoBarSeverity.warning,
                      isLong: false,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

}
