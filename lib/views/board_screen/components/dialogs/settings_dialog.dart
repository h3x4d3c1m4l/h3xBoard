import 'dart:async';

import 'package:external_display/external_display.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/app_settings_enums.dart';
import 'package:h3xboard/services/app_settings_controller.dart';
import 'package:h3xboard/widgets/themable_panel_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:scroll_edge_hint/scroll_edge_hint.dart';

/// Opens the app-wide Settings dialog. Used by the global Ctrl/Cmd+S shortcut
/// (and any future menu entry) so every entry point shares one code path.
/// Opens the preferences dialog.
///
/// [useRootNavigator] defaults to `true` (matching Flutter's `showDialog`). Pass
/// `false` when opening from inside a flyout so the dialog lands on the same
/// navigator the flyout is dismissing on — otherwise a root-level barrier stacks
/// over the still-closing flyout and leaves it visible behind the dialog.
Future<void> showSettingsDialog(BuildContext context, {bool useRootNavigator = true}) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  useRootNavigator: useRootNavigator,
  builder: (_) => const SettingsDialog(),
);

/// Edits user preferences (language, bar placement) as a draft and applies them
/// only on **OK** — nothing changes or persists on Cancel/dismiss. On OK the
/// changed keys are written via [AppSettingsController.applyChanges].
class SettingsDialog extends StatefulWidget {

  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();

}

class _SettingsDialogState extends State<SettingsDialog> {

  final AppSettingsController _settings = GetIt.I<AppSettingsController>();

  // Draft state, seeded from the current settings and mutated locally.
  late AppLanguage _language = _settings.language;
  late BarPosition _colorBarPosition = _settings.colorBarPosition;
  late bool _colorBarInside = _settings.colorBarInside;
  late BarPosition _toolBarPosition = _settings.toolBarPosition;
  late bool _toolBarInside = _settings.toolBarInside;
  late BarOrder _barOrder = _settings.barOrder;
  late String? _externalResolution = _settings.externalResolution;

  // Resolutions the connected external display reports (empty when none is
  // attached or the platform doesn't support listing them).
  List<String> _externalModes = const [];

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadExternalModes());
  }

  Future<void> _loadExternalModes() async {
    try {
      final modes = await externalDisplay.getModes();
      final unique = modes.toSet().toList()..sort((a, b) => _modeArea(b).compareTo(_modeArea(a)));
      if (mounted) setState(() => _externalModes = unique);
    } catch (_) {
      // No external display / unsupported — leave the list empty (Auto only).
    }
  }

  static int _modeArea(String mode) {
    final parts = mode.toLowerCase().split('x');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0].trim()) ?? 0) * (int.tryParse(parts[1].trim()) ?? 0);
  }

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _settings.applyChanges(
        language: _language,
        colorBarPosition: _colorBarPosition,
        colorBarInside: _colorBarInside,
        toolBarPosition: _toolBarPosition,
        toolBarInside: _toolBarInside,
        barOrder: _barOrder,
        externalResolution: _externalResolution,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.localizations.settingsDialog_saveError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;
    final theme = FluentTheme.of(context);

    return ThemablePanelDialog(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
      content: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(loc, theme),
              const SizedBox(height: 20),
              Flexible(
                child: ScrollEdgeHint.builder(
                  backgroundColor: Colors.white,
                  extent: 24,
                  builder: (context, controller) => Scrollbar(
                    controller: controller,
                    style: const ScrollbarThemeData(
                      padding: EdgeInsetsDirectional.only(end: 1, top: 4, bottom: 4),
                    ),
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.only(right: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SettingsRow(
                              label: loc.settingsDialog_language,
                              control: _buildLanguageCombo(loc),
                            ),
                            _SectionLabel(
                              icon: LucideIcons.palette,
                              text: loc.settingsDialog_section_colorBar,
                            ),
                            _SettingsRow(
                              label: loc.settingsDialog_position,
                              control: _buildPositionCombo(
                                loc,
                                value: _colorBarPosition,
                                onChanged: (p) => setState(() => _colorBarPosition = p),
                              ),
                            ),
                            _SettingsRow(
                              label: loc.settingsDialog_insideBoard,
                              control: ToggleSwitch(
                                checked: _colorBarInside,
                                onChanged: (v) => setState(() => _colorBarInside = v),
                              ),
                            ),
                            _SectionLabel(
                              icon: LucideIcons.pencil,
                              text: loc.settingsDialog_section_toolBar,
                            ),
                            _SettingsRow(
                              label: loc.settingsDialog_position,
                              control: _buildPositionCombo(
                                loc,
                                value: _toolBarPosition,
                                onChanged: (p) => setState(() => _toolBarPosition = p),
                              ),
                            ),
                            _SettingsRow(
                              label: loc.settingsDialog_insideBoard,
                              control: ToggleSwitch(
                                checked: _toolBarInside,
                                onChanged: (v) => setState(() => _toolBarInside = v),
                              ),
                            ),
                            // Order is only meaningful when both bars stack on the
                            // same edge (same position and same inside/outside).
                            if (_colorBarPosition == _toolBarPosition && _colorBarInside == _toolBarInside) ...[
                              _SectionLabel(
                                icon: LucideIcons.arrowDownUp,
                                text: loc.settingsDialog_section_barOrder,
                              ),
                              _SettingsRow(
                                label: loc.settingsDialog_order,
                                control: _buildOrderCombo(loc),
                              ),
                            ],
                            _SectionLabel(
                              icon: LucideIcons.monitor,
                              text: loc.settingsDialog_section_externalDisplay,
                            ),
                            _SettingsRow(
                              label: loc.settingsDialog_resolution,
                              control: _buildResolutionCombo(loc),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              InfoBar(
                                title: Text(_error!),
                                severity: InfoBarSeverity.error,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      rightActions: [
        Button(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(loc.settingsDialog_cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : () => unawaited(_confirm()),
          child: Text(loc.settingsDialog_ok),
        ),
      ],
    );
  }

  Widget _buildHeader(AppLocalizations loc, FluentThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.settingsDialog_title, style: theme.typography.subtitle),
              const SizedBox(height: 4),
              Text(
                loc.settingsDialog_subtitle,
                style: theme.typography.body?.copyWith(color: theme.resources.textFillColorSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.x, size: 18),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildLanguageCombo(AppLocalizations loc) {
    String label(AppLanguage l) => switch (l) {
      AppLanguage.system => loc.settingsDialog_language_system,
      AppLanguage.english => 'English',
      AppLanguage.dutch => 'Nederlands',
    };
    return ComboBox<AppLanguage>(
      value: _language,
      items: [
        for (final l in AppLanguage.values) ComboBoxItem(value: l, child: Text(label(l))),
      ],
      onChanged: (l) {
        if (l != null) setState(() => _language = l);
      },
    );
  }

  Widget _buildPositionCombo(
    AppLocalizations loc, {
    required BarPosition value,
    required ValueChanged<BarPosition> onChanged,
  }) {
    String label(BarPosition p) => switch (p) {
      BarPosition.left => loc.settingsDialog_position_left,
      BarPosition.right => loc.settingsDialog_position_right,
      BarPosition.top => loc.settingsDialog_position_top,
      BarPosition.bottom => loc.settingsDialog_position_bottom,
    };
    return ComboBox<BarPosition>(
      value: value,
      items: [
        for (final p in BarPosition.values) ComboBoxItem(value: p, child: Text(label(p))),
      ],
      onChanged: (p) {
        if (p != null) onChanged(p);
      },
    );
  }

  Widget _buildOrderCombo(AppLocalizations loc) {
    String label(BarOrder o) => switch (o) {
      BarOrder.toolBarFirst => loc.settingsDialog_order_toolBarFirst,
      BarOrder.colorBarFirst => loc.settingsDialog_order_colorBarFirst,
    };
    return ComboBox<BarOrder>(
      value: _barOrder,
      items: [
        for (final o in BarOrder.values) ComboBoxItem(value: o, child: Text(label(o))),
      ],
      onChanged: (o) {
        if (o != null) setState(() => _barOrder = o);
      },
    );
  }

  Widget _buildResolutionCombo(AppLocalizations loc) {
    // Keep the saved value selectable even if the display isn't currently
    // reporting it (e.g. it's unplugged while the dialog is open).
    final options = [
      ..._externalModes,
      if (_externalResolution != null && !_externalModes.contains(_externalResolution)) _externalResolution!,
    ];
    return ComboBox<String?>(
      value: _externalResolution,
      placeholder: Text(loc.settingsDialog_resolution_auto),
      items: [
        ComboBoxItem<String?>(value: null, child: Text(loc.settingsDialog_resolution_auto)),
        for (final m in options) ComboBoxItem<String?>(value: m, child: Text(m)),
      ],
      onChanged: (v) => setState(() => _externalResolution = v),
    );
  }

}

/// A small section header grouping related settings rows: an accent-tinted icon
/// + title, mirroring the section headings in the Board Settings dialog.
class _SectionLabel extends StatelessWidget {

  final IconData icon;
  final String text;

  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: theme.accentColor),
          ),
          const SizedBox(width: 12),
          Text(text, style: theme.typography.bodyStrong),
        ],
      ),
    );
  }

}

/// A single settings row: a label on the left, its control on the right.
class _SettingsRow extends StatelessWidget {

  final String label;
  final Widget control;

  const _SettingsRow({required this.label, required this.control});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.typography.body)),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }

}
