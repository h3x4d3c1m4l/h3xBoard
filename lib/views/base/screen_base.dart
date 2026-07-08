import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/base/screen_controller_base.dart';
import 'package:h3xboard/views/base/screen_view_base.dart';
import 'package:h3xboard/views/base/screen_view_model_base.dart';

abstract class ScreenBase<TViewModel extends ScreenViewModelBase, TController extends ScreenControllerBase<TViewModel>, TView extends ScreenViewBase<TViewModel, TController>> extends StatefulWidget {

  const ScreenBase({super.key});

  TController createController({required TViewModel viewModel, required BuildContextAccessor contextAccessor});

  TViewModel createViewModel({required BuildContextAccessor contextAccessor});

  TView createView({required TController controller, required TViewModel viewModel, required BuildContextAccessor contextAccessor});

  @override
  State<StatefulWidget> createState() => _ScreenBaseState();

}

class _ScreenBaseState<TViewModel extends ScreenViewModelBase, TController extends ScreenControllerBase<TViewModel>, TView extends ScreenViewBase<TViewModel, TController>> extends State<ScreenBase<TViewModel, TController, TView>> {

  late TController _controller;
  late TViewModel _viewModel;
  late TView _view;
  late BuildContextAccessor _contextAccessor;

  @override
  void initState() {
    _contextAccessor = BuildContextAccessor();
    _viewModel = widget.createViewModel(contextAccessor: _contextAccessor);
    _controller = widget.createController(viewModel: _viewModel, contextAccessor: _contextAccessor);
    _view = widget.createView(controller: _controller, viewModel: _viewModel, contextAccessor: _contextAccessor);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _contextAccessor.buildContext = context;
    final topSafeAreaColor = _view.topSafeAreaColor(context);
    return ColoredBox(
      color: FluentTheme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          if (topSafeAreaColor != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top,
              child: ColoredBox(color: topSafeAreaColor),
            ),
          // Most screens let the bottom safe-area inset collapse when the keyboard
          // opens (the default). A screen whose layout must not reflow behind a
          // dialog's keyboard (the board — its aspect-locked canvas would rescale)
          // opts into maintainBottomViewPadding via the view.
          SafeArea(
            bottom: _view.bottomSafeArea,
            maintainBottomViewPadding: _view.maintainBottomViewPadding,
            child: _view.body,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();

    _controller.dispose();
    _viewModel.dispose();
    _view.dispose();
  }

}
