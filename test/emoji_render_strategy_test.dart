import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/views/board_screen/components/widgets/emoji_image.dart';
import 'package:h3xboard/views/board_screen/components/widgets/emoji_widget.dart';
import 'package:vector_graphics/vector_graphics_compat.dart';

/// Guards how emoji artwork is rasterized.
///
/// `VectorGraphic`'s public constructor hardcodes [RenderingStrategy.raster] and
/// does not expose the choice, so the sharp path is only reachable through
/// `createCompatVectorGraphic`. Nothing about that is visible at the call site:
/// switching back compiles, renders, and passes every other test — it just makes
/// board emoji soft, because a 220px bitmap gets magnified by the board's scale.
void main() {
  RenderingStrategy strategyOf(WidgetTester tester) =>
      tester.widget<VectorGraphic>(find.byType(VectorGraphic)).strategy;

  testWidgets('a board emoji draws as a picture, so it survives being scaled up', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: EmojiWidget(emoji: '\u{1F600}'),
      ),
    );

    expect(
      strategyOf(tester),
      RenderingStrategy.picture,
      reason: 'the board scales emoji after layout; a cached bitmap goes soft',
    );
  });

  testWidgets('a picker tile keeps the cached raster, which is what makes the grid cheap', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 48, height: 48, child: EmojiImage(emoji: '\u{1F600}')),
      ),
    );

    expect(
      strategyOf(tester),
      RenderingStrategy.raster,
      reason: 'picker tiles are small and never scaled, so reusing one bitmap each is correct',
    );
  });
}
