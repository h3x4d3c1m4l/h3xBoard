import 'package:flutter/widgets.dart';
import 'package:h3xboard/views/base/build_context_abstractor.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';

abstract class ScreenViewBase<TViewModel extends ScreenViewModelBase, TController extends ScreenControllerBase<TViewModel>> with BuildContextAbstractor {

  final TViewModel viewModel;
  final TController controller;

  @override
  final BuildContextAccessor contextAccessor;

  BuildContext get context => contextAccessor.buildContext;

  const ScreenViewBase({
    required this.viewModel,
    required this.controller,
    required this.contextAccessor,
  });

  Widget get body;

  @mustCallSuper
  void dispose() {}

}
