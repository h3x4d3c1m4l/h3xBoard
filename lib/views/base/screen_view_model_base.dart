import 'package:h3xboard/views/base/build_context_abstractor.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:meta/meta.dart';

abstract class ScreenViewModelBase with BuildContextAbstractor {

  @override
  final BuildContextAccessor contextAccessor;

  ScreenViewModelBase({
    required this.contextAccessor,
  });

  @mustCallSuper
  void dispose() {}

}
