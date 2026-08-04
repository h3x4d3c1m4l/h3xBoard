import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/auth_link.dart';

void main() {
  group('AuthLinkAction.fromPath', () {
    test('recognises the paths the server mails out', () {
      expect(AuthLinkAction.fromPath('/verify-email'), AuthLinkAction.verifyEmail);
      expect(AuthLinkAction.fromPath('/reset-password'), AuthLinkAction.resetPassword);
      expect(AuthLinkAction.fromPath('/confirm-email-change'), AuthLinkAction.confirmEmailChange);
    });

    // Server:WebAppUrl may point at a sub-path ("https://example.com/board"),
    // and the link is built by appending — so the action is at the end, not at
    // the root.
    test('recognises a path under a hosting prefix', () {
      expect(AuthLinkAction.fromPath('/board/verify-email'), AuthLinkAction.verifyEmail);
      expect(AuthLinkAction.fromPath('/a/b/reset-password'), AuthLinkAction.resetPassword);
    });

    test('tolerates a trailing slash', () {
      expect(AuthLinkAction.fromPath('/verify-email/'), AuthLinkAction.verifyEmail);
    });

    // The suffix match must not swallow a path that merely ends in the same
    // letters — the leading slash is what makes it a segment boundary.
    test('does not match a path that only ends with the same letters', () {
      expect(AuthLinkAction.fromPath('/my-verify-email'), isNull);
      expect(AuthLinkAction.fromPath('/passwords/reset-password-help'), isNull);
    });

    test('ignores unrelated paths', () {
      expect(AuthLinkAction.fromPath('/'), isNull);
      expect(AuthLinkAction.fromPath('/boards'), isNull);
      expect(AuthLinkAction.fromPath('/view/ABC123'), isNull);
    });
  });
}
