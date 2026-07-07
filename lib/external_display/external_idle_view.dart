import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Shown on the external screen when no board is open. A calmer variant of the
/// initialization screen: no spinner, a large icon above the message, and gray
/// (rather than accent) coloring.
class ExternalIdleView extends StatelessWidget {

  const ExternalIdleView({super.key});

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
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 24,
            children: [
              Icon(LucideIcons.monitor, size: 128, color: gray),
              Text(
                context.localizations.externalDisplay_selectBoard_title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: gray),
              ),
              Text(
                context.localizations.externalDisplay_selectBoard_message,
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
