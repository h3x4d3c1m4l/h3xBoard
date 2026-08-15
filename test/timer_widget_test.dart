import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_surface.dart';
import 'package:h3xboard/views/board_screen/components/widgets/timer_widget.dart';

/// The ring mode: that it is the default, that it changes the widget's footprint
/// into a square, and that the arc a mirror draws follows from the config alone.
///
/// Time is only moved by swapping configs, never by pumping: the countdown is
/// anchored to `DateTime.now()`, which a test cannot advance.
Widget _host(Widget child) => FluentApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: FluentThemeData(accentColor: const Color(0xFF00FF80).toAccentColor()),
      home: Center(child: child),
    );

Future<void> _pump(WidgetTester tester, TimerConfig config) {
  final descriptor = descriptorFor(config);
  return tester.pumpWidget(_host(
    SizedBox.fromSize(
      size: descriptor.naturalSize(config),
      child: descriptor.buildWidget(config, (_) {}),
    ),
  ));
}

void main() {
  test('a new timer counts down on the ring', () {
    expect((TimerWidgetDescriptor.instance.defaultConfig as TimerConfig).showProgressRing, isTrue);
  });

  group('the mode decides the footprint', () {
    test('the ring is square, so the card clamps into a circle', () {
      final size = descriptorFor(const TimerConfig()).naturalSize(const TimerConfig());
      expect(size.width, size.height);
      expect(size, TimerWidget.ringSize);
    });

    test('turning the ring off returns the wide card', () {
      const digital = TimerConfig(showProgressRing: false);
      expect(descriptorFor(digital).naturalSize(digital), TimerWidget.digitalSize);
    });
  });

  group('rendering', () {
    testWidgets('the ring paints around the same readout', (tester) async {
      await _pump(tester, const TimerConfig(durationSeconds: 300));

      expect(find.text('05:00'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the digital mode paints no ring', (tester) async {
      await _pump(tester, const TimerConfig(durationSeconds: 300, showProgressRing: false));

      expect(find.text('05:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the ring gets a round card, the digital mode the family squircle', (tester) async {
      // A squircle is as round as the shared surface goes on its own: it clamps a
      // radius down, so a square card is still a rounded square at any radius.
      await _pump(tester, const TimerConfig());
      expect(tester.widget<BoardWidgetSurface>(find.byType(BoardWidgetSurface)).circular, isTrue);

      await _pump(tester, const TimerConfig(showProgressRing: false));
      expect(tester.widget<BoardWidgetSurface>(find.byType(BoardWidgetSurface)).circular, isFalse);
    });

    testWidgets('a paused timer is still, in either mode', (tester) async {
      // Load-bearing the same way it is for the dice: the catalog preview and the
      // registry sweep in board_widget_surface_test.dart build every widget from
      // its default config, and a ring that animated there would cost them a live
      // ticker each.
      await _pump(tester, const TimerConfig());
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await _pump(tester, const TimerConfig(showProgressRing: false));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a long duration still fits inside the ring', (tester) async {
      // HH:MM:SS and MM:SS.cc are both wider than the circle's inner square; the
      // FittedBox is what keeps them in it rather than overflowing.
      await _pump(tester, const TimerConfig(durationSeconds: 3600));
      expect(find.text('01:00:00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _pump(tester, const TimerConfig(durationSeconds: 60, showCentiseconds: true));
      expect(find.text('01:00.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
