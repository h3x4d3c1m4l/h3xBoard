import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/app_router.dart';

/// Wraps the whole app and listens for Alt+D to pop up a developer-only debug
/// panel from anywhere in the application. The panel is just a list of buttons
/// that trigger simple ad-hoc actions — add new ones in [_debugActions].
class DebugOverlay extends StatefulWidget {

  final Widget child;

  const DebugOverlay({required this.child, super.key});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();

}

class _DebugOverlayState extends State<DebugOverlay> {

  final _appRouter = GetIt.I<AppRouter>();

  bool _isOpen = false;

  @override
  void initState() {
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    super.initState();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyD || !HardwareKeyboard.instance.isAltPressed) {
      return false;
    }
    _openDebugPanel();
    return true;
  }

  Future<void> _openDebugPanel() async {
    // Use the router's navigator, since the [builder] context this widget lives
    // in sits above the Navigator and cannot host dialogs itself.
    final navigatorContext = _appRouter.navigatorKey.currentContext;
    if (_isOpen || navigatorContext == null) return;

    _isOpen = true;
    await showDialog<void>(
      context: navigatorContext,
      builder: (dialogContext) => _DebugPanel(actions: _debugActions(dialogContext)),
    );
    _isOpen = false;
  }

  /// Add new debug buttons here — each entry becomes a button in the panel.
  List<_DebugAction> _debugActions(BuildContext dialogContext) => [
    _DebugAction(
      label: 'Show sample dialog',
      onPressed: () => _showSampleDialog(dialogContext),
    ),
  ];

  Future<void> _showSampleDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Sample dialog'),
        content: const Text('This is a sample debug dialog. Confirm or cancel?'),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    debugPrint('Sample dialog result: $confirmed');
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

}

/// A single button in the debug panel.
class _DebugAction {

  final String label;
  final VoidCallback onPressed;

  const _DebugAction({required this.label, required this.onPressed});

}

class _DebugPanel extends StatelessWidget {

  final List<_DebugAction> actions;

  const _DebugPanel({required this.actions});

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Debug menu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          for (final action in actions)
            FilledButton(
              onPressed: action.onPressed,
              child: Text(action.label),
            ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

}
