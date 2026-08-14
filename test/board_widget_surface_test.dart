import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/theme/app_theme.dart';
import 'package:h3xboard/theme/shape_metrics.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_descriptor.dart';
import 'package:h3xboard/views/board_screen/components/widgets/board_widget_surface.dart';

/// Which board widgets sit on the shared acrylic card, and which must not.
///
/// The six card-like widgets used to spell out the same `BoxDecoration` each,
/// and they drifted — three different border alphas between them. This is the
/// guard that keeps them one family now that the card is said once.
///
/// The exclusions matter as much: a ruler and a geodreieck are instruments you
/// line up against a drawing and read *through*, so a blurred backdrop would
/// make them useless for the one thing they are for.
Widget _host(Widget child) => FluentApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: FluentThemeData(accentColor: const Color(0xFF00FF80).toAccentColor()),
      home: Center(child: child),
    );

void main() {
  /// The widgets that share the card.
  const onTheCard = <Type>{
    DigitalClockConfig,
    StopwatchConfig,
    TimerConfig,
    TodoListConfig,
    PianoConfig,
  };

  /// Instruments and objects with an identity of their own. Listed rather than
  /// inferred, so adding a widget forces a decision about which group it is in.
  const offTheCard = <Type>{
    RulerConfig,
    GeodreieckConfig,
    QrCodeConfig,
    TrafficLightConfig,
    MemoNoteConfig,
    ImageConfig,
    AnalogClockConfig,
    TextBoxConfig,
    EmojiConfig,
  };

  Future<void> pump(WidgetTester tester, BoardWidgetConfig config) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      SizedBox.fromSize(
        size: descriptorFor(config).naturalSize(config),
        child: descriptorFor(config).buildWidget(config, (_) {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('every card-like widget draws itself on the shared surface', (tester) async {
    for (final type in onTheCard) {
      final config = widgetRegistry[type]!.defaultConfig;
      await pump(tester, config);

      expect(
        find.byType(BoardWidgetSurface),
        findsAtLeast(1),
        reason: '$type should sit on the shared card rather than its own decoration',
      );
      expect(tester.takeException(), isNull, reason: '$type');
    }
  });

  testWidgets('the instruments stay transparent', (tester) async {
    for (final type in offTheCard) {
      final config = widgetRegistry[type]!.defaultConfig;
      await pump(tester, config);

      expect(
        find.byType(BoardWidgetSurface),
        findsNothing,
        reason: '$type has an identity of its own and must not be given the card',
      );
      expect(tester.takeException(), isNull, reason: '$type');
    }
  });

  testWidgets('the registry is fully accounted for', (tester) async {
    // So a new widget cannot quietly avoid the question of which group it is in.
    expect(
      widgetRegistry.keys.toSet(),
      onTheCard.union(offTheCard),
      reason: 'a widget was added without deciding whether it sits on the card',
    );
  });

  test('the surface is a squircle, like every other surface in the app', () {
    const tokens = AppBoardWidgetSurface();
    final shape = tokens.shapeOf();

    expect(shape, isA<ContinuousRectangleBorder>());
    expect(
      (shape as ContinuousRectangleBorder).borderRadius,
      BorderRadius.circular(kBoardWidgetCornerRadius),
    );
  });

  group('the corner radius clamps to what a card can take', () {
    /// The radius actually handed to the painted shape, at a given size.
    Future<double> radiusAt(WidgetTester tester, Size size) async {
      await tester.pumpWidget(_host(SizedBox.fromSize(
        size: size,
        child: const BoardWidgetSurface(child: SizedBox.expand()),
      )));

      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(BoardWidgetSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      final shape = (decorated.decoration as ShapeDecoration).shape as ContinuousRectangleBorder;
      return shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
    }

    testWidgets('a card with room to spare gets the full radius', (tester) async {
      expect(await radiusAt(tester, const Size(940, 764)), kBoardWidgetCornerRadius);
    });

    testWidgets('a short card stops at its own pill rather than going misshapen', (tester) async {
      // The clock is 300x100. Past half the shortest side a continuous rectangle
      // has no straight edge left to run, and the corners meet in the middle of
      // the card — so the token is a ceiling to aim at, not a promise.
      expect(await radiusAt(tester, const Size(300, 100)), 50);
      expect(await radiusAt(tester, const Size(160, 88)), 44);
    });

    testWidgets('raising the token cannot break the smallest card', (tester) async {
      // The point of the clamp: this token gets nudged upward whenever the cards
      // want to look softer, and nobody should have to check every widget's
      // proportions each time.
      expect(await radiusAt(tester, const Size(300, 100)), lessThanOrEqualTo(50));
    });
  });
}
