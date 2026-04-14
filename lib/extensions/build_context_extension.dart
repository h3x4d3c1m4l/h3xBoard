import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';

extension BuildContextExtension on BuildContext {

  NavigatorState get navigator => Navigator.of(this);
  NavigatorState get rootNavigator => Navigator.of(this, rootNavigator: true);

  AppLocalizations get localizations => AppLocalizations.of(this)!;

}
