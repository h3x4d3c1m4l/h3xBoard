import 'package:h3xboard/models/app_settings_enums.dart';
import 'package:h3xboard/services/h3x_board_api_client.dart';
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

  AppSettingsControllerBase(this._api);

  static const String keyLanguage = 'ui.language';
  static const String keyColorBarPosition = 'ui.colorBar.position';
  static const String keyColorBarInside = 'ui.colorBar.inside';
  static const String keyToolBarPosition = 'ui.toolBar.position';
  static const String keyToolBarInside = 'ui.toolBar.inside';

  final H3xBoardApiClient _api;

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
  }) async {
    if (language != _language) {
      await _api.setSetting(keyLanguage, language.wireValue);
      _language = language;
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
  }

}
