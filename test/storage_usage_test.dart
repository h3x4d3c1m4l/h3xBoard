import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/models/api/storage_usage.dart';
import 'package:h3xboard/views/components/dialogs/file_manager/file_manager_usage_bar.dart';

/// The storage-quota contract, on the two points where the server's shape and
/// the client's rendering have to agree.
///
/// `quotaBytes` is **absent, not null-valued and not zero**, for an unlimited
/// account — the RPC connection drops null fields. Decoding that as "no quota"
/// rather than as a missing field is what keeps an unlimited account from
/// rendering a full bar.
void main() {
  Widget wrap(Widget child) => FluentApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScaffoldPage(content: Center(child: child)),
      );

  group('StorageUsage decoding', () {
    test('an absent quotaBytes is an unlimited account', () {
      final usage = StorageUsage.fromJson(const {'usedBytes': 5242880});

      expect(usage.usedBytes, 5242880);
      expect(usage.quotaBytes, isNull);
      expect(usage.isLimited, isFalse);
      expect(usage.fraction, isNull);
    });

    test('a present quotaBytes is a ceiling to measure against', () {
      final usage = StorageUsage.fromJson(const {'usedBytes': 5242880, 'quotaBytes': 10485760});

      expect(usage.isLimited, isTrue);
      expect(usage.fraction, 0.5);
    });

    test('the bounded overshoot the server allows does not overflow the bar', () {
      // The server's quota check and its insert are not one transaction, so two
      // concurrent uploads can both pass and land the account slightly over.
      const usage = StorageUsage(usedBytes: 120, quotaBytes: 100);

      expect(usage.fraction, 1.0);
    });

    test('an empty account is at zero, not at null', () {
      const usage = StorageUsage(usedBytes: 0, quotaBytes: 100);

      expect(usage.fraction, 0.0);
    });
  });

  group('FileManagerUsageBar', () {
    testWidgets('says nothing at all while the number is unknown', (tester) async {
      // Also the case against a server that has no files.v1.usage yet: there is
      // no useful version of this widget without a figure.
      await tester.pumpWidget(wrap(const FileManagerUsageBar(usage: null)));

      expect(find.byType(ProgressBar), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a limited account gets a bar and both figures', (tester) async {
      await tester.pumpWidget(wrap(const FileManagerUsageBar(
        usage: StorageUsage(usedBytes: 5 * 1024 * 1024, quotaBytes: 1024 * 1024 * 1024),
      )));

      expect(find.byType(ProgressBar), findsOneWidget);
      expect(find.text('5.0 MB of 1.0 GB used'), findsOneWidget);
    });

    testWidgets('an unlimited account gets the figure but no bar', (tester) async {
      // An empty progress track would suggest a ceiling that does not exist.
      await tester.pumpWidget(wrap(const FileManagerUsageBar(usage: StorageUsage(usedBytes: 2048))));

      expect(find.byType(ProgressBar), findsNothing);
      expect(find.text('2 KB used'), findsOneWidget);
    });

    testWidgets('a cramped footer ellipsizes instead of overflowing', (tester) async {
      // The panel dialog's actions row hands a plain child unbounded width, so
      // the bar has to survive being squeezed rather than paint over the edge.
      await tester.pumpWidget(wrap(const SizedBox(
        width: 150,
        child: Row(children: [
          Flexible(
            child: FileManagerUsageBar(
              usage: StorageUsage(usedBytes: 5 * 1024 * 1024, quotaBytes: 1024 * 1024 * 1024),
            ),
          ),
          Spacer(),
        ]),
      )));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a full account says so instead of reciting two equal numbers', (tester) async {
      await tester.pumpWidget(wrap(const FileManagerUsageBar(
        usage: StorageUsage(usedBytes: 1024, quotaBytes: 1024),
      )));

      expect(find.text("You're out of storage space."), findsOneWidget);
    });
  });
}
