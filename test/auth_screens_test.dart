import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:h3xboard/l10n/generated/app_localizations.dart';
import 'package:h3xboard/services/cookies/cookie_store.dart';
import 'package:h3xboard/services/h3x_board_auth_service.dart';
import 'package:h3xboard/theme/theme.dart';
import 'package:h3xboard/views/components/dialogs/forgot_password_dialog.dart';
import 'package:h3xboard/views/confirm_email_change_screen/confirm_email_change_screen.dart';
import 'package:h3xboard/views/reset_password_screen/reset_password_screen.dart';
import 'package:h3xboard/views/unverified_screen/unverified_screen.dart';
import 'package:h3xboard/views/verify_email_screen/verify_email_screen.dart';

/// Hosts one account-lifecycle screen with the app's theme and localizations —
/// what these screens read from context and nothing else, so no router or
/// session is needed to render them.
Widget _host(Widget child) => FluentApp(
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  setUpAll(() {
    // The screens resolve the auth service when their controller is built. None
    // of the cases below reaches the network — a missing token is decided
    // locally — so an unroutable base URL is enough to satisfy the lookup.
    GetIt.I.registerSingleton<H3xBoardAuthService>(
      H3xBoardAuthService.create('http://127.0.0.1:1', CookieStore()),
    );
  });

  tearDownAll(GetIt.I.reset);

  group('UnverifiedScreen', () {
    testWidgets('names the address the verification mail went to', (tester) async {
      await tester.pumpWidget(_host(const UnverifiedScreen(email: 'alice@example.com')));
      await tester.pump();

      expect(find.textContaining('alice@example.com'), findsOneWidget);
      expect(find.textContaining('24 hours'), findsOneWidget);
      // With an address in hand there is nothing to type — just a button.
      expect(find.byType(TextBox), findsNothing);
    });

    testWidgets('asks for an address when it does not know one', (tester) async {
      await tester.pumpWidget(_host(const UnverifiedScreen()));
      await tester.pump();

      expect(find.byType(TextBox), findsOneWidget);
    });
  });

  // Every token screen can be reached without a token: the token is stripped
  // from the URL as soon as it is read, so a reload arrives empty. That must
  // read as an expired link, not as a crash or a form that cannot work.
  group('a token screen reached without a token', () {
    testWidgets('VerifyEmailScreen shows the dead-link panel', (tester) async {
      await tester.pumpWidget(_host(const VerifyEmailScreen()));
      await tester.pump();

      expect(find.textContaining('invalid or has expired'), findsOneWidget);
      expect(find.byType(ProgressRing), findsNothing);
    });

    testWidgets('ResetPasswordScreen offers a new link instead of the form', (tester) async {
      await tester.pumpWidget(_host(const ResetPasswordScreen()));
      await tester.pump();

      expect(find.textContaining('invalid or has expired'), findsOneWidget);
      expect(find.byType(TextBox), findsNothing);
    });

    testWidgets('ConfirmEmailChangeScreen shows the dead-link panel', (tester) async {
      await tester.pumpWidget(_host(const ConfirmEmailChangeScreen()));
      await tester.pump();

      expect(find.textContaining('invalid or has expired'), findsOneWidget);
    });
  });

  group('ForgotPasswordDialog', () {
    testWidgets('opens with the address already typed on the login screen', (tester) async {
      await tester.pumpWidget(_host(
        const ForgotPasswordDialog(initialEmail: 'alice@example.com'),
      ));
      await tester.pump();

      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.textContaining('valid for 1 hour'), findsOneWidget);
    });
  });
}
