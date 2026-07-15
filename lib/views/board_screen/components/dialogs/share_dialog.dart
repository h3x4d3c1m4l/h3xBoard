import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/services/live_share/live_share_session_service.dart';
import 'package:h3xboard/services/server_controller.dart';
import 'package:h3xboard/views/components/dialogs/themable_content_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

/// Opens the live-share dialog: start/stop sharing this board session and,
/// while sharing, show the viewer code, link, QR and live viewer count.
Future<void> showShareDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const ShareDialog(),
  );
}

class ShareDialog extends StatefulWidget {

  const ShareDialog({super.key});

  @override
  State<ShareDialog> createState() => _ShareDialogState();

}

class _ShareDialogState extends State<ShareDialog> {

  final LiveShareSessionService _session = GetIt.I<LiveShareSessionService>();

  bool _busy = false;
  bool _failed = false;

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await _session.startSharing();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      await _session.stopSharing();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The URL a viewer opens for [code], or null when none can be built (a
  /// native presenter against a server without `webAppUrl` configured).
  /// Flutter web uses hash-based routing, hence the `#`.
  static String? _viewerLink(String code) {
    final origin = kIsWeb
        ? Uri.base.origin
        : GetIt.I<ServerController>().serverInfo.value?.webAppUrl;
    if (origin == null || origin.isEmpty) return null;
    return '${ServerController.normalizeUrl(origin)}/#/view/$code';
  }

  /// `ABC123` → `ABC-123`: grouped for reading aloud, matching what the
  /// viewer's code entry strips back out.
  static String _formatCode(String code) => code.length == 6 ? '${code.substring(0, 3)}-${code.substring(3)}' : code;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final code = _session.code;
        return code == null ? _buildStart() : _buildSharing(code);
      },
    );
  }

  Widget _buildStart() {
    return ThemableContentDialog(
      title: Text(context.localizations.shareDialog_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(context.localizations.shareDialog_description),
          if (_failed)
            InfoBar(
              title: Text(context.localizations.shareDialog_startError),
              severity: InfoBarSeverity.error,
            ),
        ],
      ),
      actions: [
        Button(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.localizations.shareDialog_close),
        ),
        FilledButton(
          onPressed: _busy ? null : () => unawaited(_start()),
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: ProgressRing(strokeWidth: 2))
              : Text(context.localizations.shareDialog_start),
        ),
      ],
    );
  }

  Widget _buildSharing(String code) {
    final theme = FluentTheme.of(context);
    final link = _viewerLink(code);
    return ThemableContentDialog(
      title: Text(context.localizations.shareDialog_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(context.localizations.shareDialog_codeLabel, textAlign: TextAlign.center),
          Text(
            _formatCode(code),
            textAlign: TextAlign.center,
            style: theme.typography.titleLarge?.copyWith(
              letterSpacing: 4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          // Scanning the QR takes viewers straight to the board; without a
          // link it still carries the code for a manual join.
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: PrettyQrView.data(
                data: link ?? code,
                decoration: const PrettyQrDecoration(
                  shape: PrettyQrSmoothSymbol(color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
          ),
          if (link != null)
            Row(
              spacing: 4,
              children: [
                Expanded(
                  child: Text(
                    link,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption,
                  ),
                ),
                Tooltip(
                  message: context.localizations.shareDialog_copyLink,
                  child: IconButton(
                    icon: const Icon(LucideIcons.copy, size: 16),
                    onPressed: () => unawaited(Clipboard.setData(ClipboardData(text: link))),
                  ),
                ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              const Icon(LucideIcons.users, size: 16),
              Text(context.localizations.shareDialog_viewerCount(_session.viewerCount)),
            ],
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.localizations.shareDialog_close),
        ),
        FilledButton(
          onPressed: _busy ? null : () => unawaited(_stop()),
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: ProgressRing(strokeWidth: 2))
              : Text(context.localizations.shareDialog_stop),
        ),
      ],
    );
  }

}
