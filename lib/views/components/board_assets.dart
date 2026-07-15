import 'package:fluent_ui/fluent_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/services/board_asset_resolver.dart';
import 'package:h3xboard/services/h3x_board_file_service.dart';

/// Provides the [BoardAssetResolver] board-rendering widgets (image widgets,
/// background images) use to fetch file bytes.
///
/// The editor doesn't wrap its tree — resolution falls back to the
/// authenticated file service from GetIt. Environments without app services
/// (the external-display isolate) or with a different transport (the web
/// viewer) wrap their board subtree in a [BoardAssets] scope instead.
class BoardAssets extends InheritedWidget {

  final BoardAssetResolver resolver;

  const BoardAssets({super.key, required this.resolver, required super.child});

  /// The nearest scope's resolver, falling back to the authenticated file
  /// service when the app services exist. Returns null when neither is
  /// available (e.g. the external-display isolate outside a scope) — callers
  /// render their placeholder in that case rather than throwing mid-build.
  static BoardAssetResolver? maybeResolverOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BoardAssets>();
    if (scope != null) return scope.resolver;
    if (GetIt.I.isRegistered<H3xBoardFileService>()) {
      return _authedFallback ??= AuthedBoardAssetResolver(GetIt.I<H3xBoardFileService>());
    }
    return null;
  }

  // The file service is a stable app-wide singleton (it survives base-URL
  // changes), so one fallback resolver instance can be shared forever.
  static BoardAssetResolver? _authedFallback;

  @override
  bool updateShouldNotify(BoardAssets oldWidget) => resolver != oldWidget.resolver;

}
