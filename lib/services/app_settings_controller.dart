import 'package:h3xboard/extensions/app_language_extension.dart';
import 'package:h3xboard/models/app_settings_enums.dart';
import 'package:h3xboard/models/laser_pointer.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:mobx/mobx.dart';

part 'app_settings_controller.g.dart';

/// App-wide, per-user preferences backed by the server's `settings.v1.*`
/// endpoints. Each setting maps to one dotted key; values are stored as JSON.
///
/// Registered as a GetIt singleton and observed by [BoardApp] (for the locale)
/// and the board layout (for bar placement). [load] runs once at startup after
/// the socket connects; the Settings dialog calls [applyChanges] on OK.
class AppSettingsController = AppSettingsControllerBase with _$AppSettingsController;

abstract class AppSettingsControllerBase with Store {

  AppSettingsControllerBase(this._api, this._auth);

  static const String keyLanguage = 'ui.language';
  static const String keyColorBarPosition = 'ui.colorBar.position';
  static const String keyColorBarInside = 'ui.colorBar.inside';
  static const String keyToolBarPosition = 'ui.toolBar.position';
  static const String keyToolBarInside = 'ui.toolBar.inside';
  static const String keyBarOrder = 'ui.bars.order';
  static const String keyExternalResolution = 'ui.externalDisplay.resolution';
  static const String keyLaserColor = 'ui.laser.color';

  final H3xBoardApiClient _api;

  // Only used to keep the server's e-mail language in step with [language];
  // every other setting lives behind the JSON-RPC client.
  final H3xBoardAuthService _auth;

  /// Display language. [AppLanguage.system] follows the device.
  @readonly
  AppLanguage _language = AppLanguage.system;

  /// Edge the color selection bar is docked to. Defaults to today's layout.
  @readonly
  BarPosition _colorBarPosition = BarPosition.left;

  /// Whether the color selection bar floats over the board (true) or sits beside it.
  @readonly
  bool _colorBarInside = false;

  /// Edge the tool bar is docked to. Defaults to today's layout.
  @readonly
  BarPosition _toolBarPosition = BarPosition.top;

  /// Whether the tool bar floats over the board (true) or sits beside it.
  @readonly
  bool _toolBarInside = false;

  /// When both bars share an edge, which one is placed first. Ignored when the
  /// bars sit on different edges.
  @readonly
  BarOrder _barOrder = BarOrder.toolBarFirst;

  /// Preferred external-display resolution as `"WxH"` (pixels), or `null` to let
  /// the display use its highest-resolution mode. Applied by [ExternalDisplayMirror].
  @readonly
  String? _externalResolution;

  /// Colour of the virtual laser pointer. A personal preference rather than
  /// board content, so it lives here and follows the user across boards.
  @readonly
  LaserColor _laserColor = LaserColor.red;

  /// Loads all settings from the server into the observables. Missing or invalid
  /// values fall back to their defaults; unknown keys are ignored. Never throws —
  /// a failed load simply leaves the defaults in place.
  @action
  Future<void> load() async {
    final Map<String, dynamic> values;
    try {
      values = await _api.getAllSettings();
    } catch (_) {
      return;
    }
    _language = AppLanguage.fromWire(values[keyLanguage]);
    _colorBarPosition = BarPosition.fromWire(values[keyColorBarPosition], BarPosition.left);
    _colorBarInside = values[keyColorBarInside] as bool? ?? false;
    _toolBarPosition = BarPosition.fromWire(values[keyToolBarPosition], BarPosition.top);
    _toolBarInside = values[keyToolBarInside] as bool? ?? false;
    _barOrder = BarOrder.fromWire(values[keyBarOrder]);
    _externalResolution = values[keyExternalResolution] as String?;
    _laserColor = LaserColor.values.firstWhere(
      (c) => c.name == values[keyLaserColor],
      orElse: () => LaserColor.red,
    );
  }

  /// Persists and applies the laser colour on its own. Unlike the settings in
  /// [applyChanges] this one is picked straight from the board's top bar rather
  /// than the Settings dialog, so it commits immediately — and optimistically,
  /// since a failed write must not leave the dot a different colour than the
  /// swatch the presenter just tapped.
  @action
  Future<void> setLaserColor(LaserColor color) async {
    if (color == _laserColor) return;
    _laserColor = color;
    try {
      await _api.setSetting(keyLaserColor, color.name);
    } catch (_) {
      // Keep the picked colour for this session; the next successful write wins.
    }
  }

  /// Persists and applies a batch of edits, issuing a `settings.v1.set` only for
  /// keys whose value actually changed. Observables update optimistically as each
  /// key succeeds; if a `set` throws it propagates to the caller (the dialog).
  @action
  Future<void> applyChanges({
    required AppLanguage language,
    required BarPosition colorBarPosition,
    required bool colorBarInside,
    required BarPosition toolBarPosition,
    required bool toolBarInside,
    required BarOrder barOrder,
    required String? externalResolution,
  }) async {
    if (language != _language) {
      await _api.setSetting(keyLanguage, language.wireValue);
      _language = language;
      await _syncEmailLocale(language);
    }
    if (colorBarPosition != _colorBarPosition) {
      await _api.setSetting(keyColorBarPosition, colorBarPosition.wireValue);
      _colorBarPosition = colorBarPosition;
    }
    if (colorBarInside != _colorBarInside) {
      await _api.setSetting(keyColorBarInside, colorBarInside);
      _colorBarInside = colorBarInside;
    }
    if (toolBarPosition != _toolBarPosition) {
      await _api.setSetting(keyToolBarPosition, toolBarPosition.wireValue);
      _toolBarPosition = toolBarPosition;
    }
    if (toolBarInside != _toolBarInside) {
      await _api.setSetting(keyToolBarInside, toolBarInside);
      _toolBarInside = toolBarInside;
    }
    if (barOrder != _barOrder) {
      await _api.setSetting(keyBarOrder, barOrder.wireValue);
      _barOrder = barOrder;
    }
    if (externalResolution != _externalResolution) {
      await _api.setSetting(keyExternalResolution, externalResolution);
      _externalResolution = externalResolution;
    }
  }

  /// Tells the server which language to mail this user in, so notifications and
  /// verification links follow the UI language.
  ///
  /// Best-effort on purpose: this is a side effect of saving preferences, and a
  /// rate limit or a hiccup here must not fail the dialog over a setting the
  /// user did not ask about. The next language change tries again.
  Future<void> _syncEmailLocale(AppLanguage language) async {
    try {
      await _auth.setLocale(language.displayLocaleTag);
    } catch (_) {
      // Keep the saved UI language; the server falls back to its own default.
    }
  }

}
