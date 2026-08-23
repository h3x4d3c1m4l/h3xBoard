import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/api/storage_usage.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/views/components/file_format.dart';

/// How full the account's storage is, shown in the file manager's footer.
///
/// It renders the **server's** figure rather than a sum of the listed files.
/// Board screenshots count against the quota but never appear in a folder
/// listing, so anything added up here would read lower than the number the
/// upload is actually refused against.
///
/// An unlimited account has no ceiling to draw, so it gets the used figure and
/// no bar — an empty progress track would suggest a limit that does not exist.
class FileManagerUsageBar extends StatelessWidget {

  /// Null while it is still being fetched, and also when the server does not
  /// answer `files.v1.usage` at all — an older build than this one. Both mean
  /// "say nothing", which is why they are not told apart: there is no version of
  /// this widget that is useful without a number.
  final StorageUsage? usage;

  const FileManagerUsageBar({super.key, required this.usage});

  static const double _trackWidth = 120;
  static const double _gap = 10;
  static const double _minTextWidth = 80;

  @override
  Widget build(BuildContext context) {
    final current = usage;
    if (current == null) return const SizedBox.shrink();

    final loc = context.localizations;
    final theme = FluentTheme.of(context);
    final quota = current.quotaBytes;
    final fraction = current.fraction;
    final isFull = fraction != null && current.usedBytes >= quota!;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The footer splits its free space between this and the close button, so
        // how much there is depends on the dialog's width. Below the point where
        // the track and a readable figure both fit, the figure wins — a 20px
        // stub of progress bar says less than the number it was drawn from.
        final hasRoomForTrack = fraction != null && constraints.maxWidth >= _trackWidth + _gap + _minTextWidth;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasRoomForTrack) ...[
              SizedBox(
                width: _trackWidth,
                child: ProgressBar(
                  value: fraction * 100,
                  activeColor: isFull ? context.appTheme.colors.destructive : null,
                ),
              ),
              const SizedBox(width: _gap),
            ],
            Flexible(
              child: Text(
                isFull
                    ? loc.fileManager_usageFull
                    : quota == null
                        ? loc.fileManager_usageUnlimited(formatFileSize(current.usedBytes))
                        : loc.fileManager_usage(formatFileSize(current.usedBytes), formatFileSize(quota)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption?.copyWith(
                  color: isFull ? context.appTheme.colors.destructive : theme.resources.textFillColorSecondary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

}
