import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/board_screen/components/widgets/text_box_widget.dart';

void main() {
  // Measure against a bundled family. Going through google_fonts here would kick
  // off an async font load that outlives the test and fails it after it passed.
  setUpAll(() => TextBoxWidget.debugFontFamily = 'Roboto');

  group('TextBoxWidget sizing', () {
    // ManipulableBoardWidget lays the child out at naturalSize and then stretches
    // it with BoxFit.fill, so a size that disagrees with what the child wants
    // distorts the glyphs instead of clipping them. These pin the agreement.

    test('empty and whitespace-only text fall back to the placeholder size', () {
      // Guards the toolbar button, which starts from an empty config — a
      // zero-sized default would be invisible and impossible to grab.
      expect(TextBoxWidget.sizeFor(const TextBoxConfig()), TextBoxWidget.placeholderSize);
      expect(TextBoxWidget.sizeFor(const TextBoxConfig(text: '   \n  ')), TextBoxWidget.placeholderSize);
    });

    test('the reported size is the measured text plus the highlight padding', () {
      const config = TextBoxConfig(text: 'Hello');
      final (:textSize, :padding) = TextBoxWidget.measure(config);

      final size = TextBoxWidget.sizeFor(config);

      // RoundedBackgroundText reports only the text box and paints its background
      // outside it, so the padding must be real space in our size or the
      // highlight gets clipped at the edges.
      expect(size.width, textSize.width + padding.horizontal);
      expect(size.height, textSize.height + padding.vertical);
      expect(padding.horizontal, greaterThan(0));
      expect(padding.vertical, greaterThan(0));
    });

    test('text wraps at contentWidth instead of growing without bound', () {
      const short = TextBoxConfig(text: 'Hi');
      final long = TextBoxConfig(text: List.filled(80, 'word').join(' '));

      final longSize = TextBoxWidget.sizeFor(long);
      final (:textSize, :padding) = TextBoxWidget.measure(long);

      expect(textSize.width, lessThanOrEqualTo(TextBoxWidget.contentWidth));
      expect(longSize.width, lessThanOrEqualTo(TextBoxWidget.contentWidth + padding.horizontal));
      expect(longSize.height, greaterThan(TextBoxWidget.sizeFor(short).height));
    });

    test('a larger font size yields a larger box', () {
      final small = TextBoxWidget.sizeFor(const TextBoxConfig(text: 'Hello', fontSize: 32));
      final large = TextBoxWidget.sizeFor(const TextBoxConfig(text: 'Hello', fontSize: 128));

      expect(large.height, greaterThan(small.height));
    });
  });
}
