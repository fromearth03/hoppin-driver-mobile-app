import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  tearDown(hoppinClearCapturedAuthLink);

  group('hoppinCaptureAuthLink', () {
    test('keeps token_hash from path query', () {
      hoppinCaptureAuthLink(Uri.parse(
        'https://driver.hoppin.tech/reset?token_hash=abc&type=invite',
      ));
      final link = hoppinAuthLinkParams();
      expect(link.tokenHash, 'abc');
      expect(link.type, 'invite');
    });

    test('keeps token_hash from hash-router fragment', () {
      hoppinCaptureAuthLink(Uri.parse(
        'https://driver.hoppin.tech/#/reset?token_hash=xyz&type=magiclink',
      ));
      final link = hoppinAuthLinkParams();
      expect(link.tokenHash, 'xyz');
      expect(link.type, 'magiclink');
    });

    test('survives a later URI without query', () {
      hoppinCaptureAuthLink(Uri.parse(
        'https://driver.hoppin.tech/reset?token_hash=keep&type=invite',
      ));
      final afterRouter = hoppinAuthLinkParams(
        Uri.parse('https://driver.hoppin.tech/#/reset'),
      );
      expect(afterRouter.tokenHash, 'keep');
    });
  });

  group('hoppinResetErrorMessage', () {
    test('does not call a leaked password expired', () {
      expect(
        hoppinResetErrorMessage(AuthException('Password has been leaked')),
        contains('too weak'),
      );
    });

    test('maps missing token to expired copy', () {
      expect(
        hoppinResetErrorMessage(StateError('no reset session')),
        contains('expired or is invalid'),
      );
    });
  });
}
