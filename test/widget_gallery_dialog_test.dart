import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/theme/theme.dart';
import 'package:h3xboard/views/components/dialogs/widget_gallery_dialog.dart';

/// Hosts the gallery under [theme], so the same test can run it with the app's
/// real theme and with a bare fluent one.
Widget _host(FluentThemeData theme) => FluentApp(
      theme: theme,
      home: const WidgetGalleryDialog(),
    );

void main() {
  group('WidgetGalleryDialog', () {
    // The gallery exists to preview every fluent button type at once, which
    // makes it the one place a theme change is exercised against all of them —
    // including the ones fluent builds out of a plain Button (ComboBox,
    // DropDownButton, SplitButton). If it builds, they all resolved a style.

    testWidgets('builds every button sample under the app theme', (tester) async {
      await tester.pumpWidget(_host(buildAppTheme()));

      expect(find.text('Button'), findsWidgets);
      expect(find.byType(FilledButton), findsWidgets);
      expect(find.byType(OutlinedButton), findsWidgets);
      expect(find.byType(HyperlinkButton), findsWidgets);
      expect(find.byType(IconButton), findsWidgets);
      expect(find.byType(ToggleButton), findsWidgets);
      expect(find.byType(ToggleSwitch), findsOneWidget);
      expect(find.byType(SplitButton), findsOneWidget);
      expect(find.byType(DropDownButton), findsOneWidget);
      expect(find.byType(ComboBox<String>), findsOneWidget);
    });

    testWidgets('switching the backdrop repaints the samples', (tester) async {
      await tester.pumpWidget(_host(buildAppTheme()));

      await tester.tap(find.text('Chalkboard'));
      await tester.pumpAndSettle();

      expect(find.byType(ComboBox<String>), findsOneWidget);
    });

    testWidgets('renders without the AppTheme extension registered', (tester) async {
      // Widget tests (and any stray FluentApp) theme their subtree themselves, so
      // `context.appTheme` has to fall back instead of null-checking.
      await tester.pumpWidget(_host(FluentThemeData()));

      expect(find.byType(ComboBox<String>), findsOneWidget);
    });
  });
}
