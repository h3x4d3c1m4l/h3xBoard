import 'dart:ui';

import 'package:flutter/widgets.dart' show basicLocaleListResolution;
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/app_settings_enums.dart';

extension AppLanguageExtension on AppLanguage {

  /// The BCP-47 tag of the language the app is *actually* rendered in for this
  /// setting — what the server should mail this user in.
  ///
  /// [AppLanguage.system] has no locale of its own, so it is resolved the same
  /// way `FluentApp` resolves it: the device's preferred languages matched
  /// against the ones the app ships. Sending the raw device tag instead would
  /// promise German mail to someone whose app is showing English.
  String get displayLocaleTag =>
      (locale ?? basicLocaleListResolution(
        PlatformDispatcher.instance.locales,
        AppLocalizations.supportedLocales,
      )).toLanguageTag();

}
