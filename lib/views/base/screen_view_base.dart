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

  /// Whether the screen's [SafeArea] keeps its bottom inset reserved while the
  /// software keyboard is up (see [SafeArea.maintainBottomViewPadding]).
  ///
  /// Defaults to `false` — the bottom inset collapses under the keyboard, which
  /// is what most screens want. Override to `true` on a screen whose layout must
  /// not reflow when a dialog on top of it opens the keyboard.
  bool get maintainBottomViewPadding => false;

  /// Whether the screen's [SafeArea] insets its bottom edge (default `true`).
  ///
  /// Override to `false` on a screen that scrolls its own content — so the
  /// content can scroll all the way to the physical bottom edge (and under a
  /// scroll shadow) instead of stopping at a hard safe-area line. Such a screen
  /// is responsible for adding [MediaQueryData.viewPadding]'s bottom to its own
  /// scroll padding so the last item still clears the home indicator.
  bool get bottomSafeArea => true;

  @mustCallSuper
  void dispose() {}

}
