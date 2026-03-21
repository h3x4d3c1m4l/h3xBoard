import 'package:fluent_ui/fluent_ui.dart';

extension BuildContextExtension on BuildContext {

  NavigatorState get navigator => Navigator.of(this);
  NavigatorState get rootNavigator => Navigator.of(this, rootNavigator: true);

}
