import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';

/// This mixin makes several objects (that normally needs to be accessed using [BuildContext]) easier accessible from screen view models and controllers.
mixin BuildContextAbstractor {

  BuildContextAccessor get contextAccessor;
  BuildContext get _context => contextAccessor.buildContext;

  NavigatorState get navigator => _context.navigator;
  NavigatorState get rootNavigator => _context.rootNavigator;

  AppLocalizations get localizations => _context.localizations;

}
