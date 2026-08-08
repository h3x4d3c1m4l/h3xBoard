import 'package:fluent_ui/fluent_ui.dart';
import 'package:h3xboard/extensions/build_context_extension.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_metrics.dart';
import 'package:h3xboard/views/board_screen/components/widgets/code_playground/code_playground_style.dart';

/// What the last run produced.
///
/// stdout and stderr are shown in one stream, in that order, because that is how
/// a terminal shows them and how a pupil will expect to read them — but stderr is
/// coloured so a traceback is never mistaken for output. The panel scrolls; the
/// widget's own height never changes with the amount of output, which is what
/// keeps `naturalSize` honest.
class OutputPanel extends StatelessWidget {

  final CodePlaygroundConfig config;
  final bool isRunning;

  const OutputPanel({super.key, required this.config, required this.isRunning});

  bool get _hasRun => config.exitCode != null;

  @override
  Widget build(BuildContext context) {
    final loc = context.localizations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: kPanelLabelHeight,
          child: Row(
            children: [
              Text(loc.codePlayground_output.toUpperCase(), style: CodePlaygroundStyle.caption()),
              const Spacer(),
              if (_hasRun && !isRunning) _buildStatus(context),
            ],
          ),
        ),
        const SizedBox(height: kPanelLabelGap),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(kPanelPad),
            decoration: CodePlaygroundStyle.wellDecoration(),
            child: _buildBody(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStatus(BuildContext context) {
    final loc = context.localizations;
    final failed = config.exitCode != 0;

    return Text(
      failed
          ? loc.codePlayground_statusFailed
          : loc.codePlayground_statusFinished(config.durationMs),
      style: CodePlaygroundStyle.label(
        fontSize: kLabelFontSize,
        fontWeight: FontWeight.w600,
        color: failed ? CodePlaygroundStyle.error : CodePlaygroundStyle.success,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final loc = context.localizations;

    if (isRunning) {
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: Text(
          loc.codePlayground_running,
          style: CodePlaygroundStyle.mono(
            fontSize: kOutputFontSize,
            color: CodePlaygroundStyle.muted,
          ),
        ),
      );
    }

    // Never run is not the same as ran and printed nothing, and saying so saves a
    // pupil wondering whether their program is broken.
    if (!_hasRun && config.stdout.isEmpty && config.stderr.isEmpty) {
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: Text(
          loc.codePlayground_outputEmpty,
          style: CodePlaygroundStyle.mono(
            fontSize: kOutputFontSize,
            color: CodePlaygroundStyle.faint,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: Text.rich(
          TextSpan(
            children: [
              if (config.stdout.isNotEmpty)
                TextSpan(
                  text: config.stdout,
                  style: CodePlaygroundStyle.mono(
                    fontSize: kOutputFontSize,
                    color: CodePlaygroundStyle.onCard,
                  ),
                ),
              if (config.stderr.isNotEmpty)
                TextSpan(
                  text: config.stderr,
                  style: CodePlaygroundStyle.mono(
                    fontSize: kOutputFontSize,
                    color: CodePlaygroundStyle.error,
                  ),
                ),
              if (config.outputTruncated)
                TextSpan(
                  text: '\n${loc.codePlayground_outputTruncated}',
                  style: CodePlaygroundStyle.mono(
                    fontSize: kOutputFontSize,
                    fontWeight: FontWeight.w600,
                    color: CodePlaygroundStyle.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
