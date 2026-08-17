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

    test('treats implicit magic-link hash as a callback', () {
      hoppinCaptureAuthLink(Uri.parse(
        'https://driver.hoppin.tech/reset#access_token=aaa&type=magiclink',
      ));
      final link = hoppinAuthLinkParams();
      expect(link.isCallback, isTrue);
      expect(link.tokenHash, isEmpty);
      expect(link.type, 'magiclink');
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

  group('hoppinMarkResetConsumed', () {
    test('stops treating a captured invite as a live callback', () {
      hoppinCaptureAuthLink(Uri.parse(
        'https://driver.hoppin.tech/reset?token_hash=abc&type=invite',
      ));
      expect(
        hoppinIsAuthCallback(Uri.parse('https://driver.hoppin.tech/')),
        isTrue,
      );
      hoppinMarkResetConsumed(passwordUpdated: true);
      expect(
        hoppinIsAuthCallback(Uri.parse('https://driver.hoppin.tech/')),
        isFalse,
      );
      expect(hoppinTakePasswordUpdatedNotice(), isTrue);
      expect(hoppinTakePasswordUpdatedNotice(), isFalse);
    });
  });

  group('hoppinPasswordAlreadySet', () {
    test('detects GoTrue same-password errors', () {
      expect(
        hoppinPasswordAlreadySet(
          AuthException('New password should be different from the old password.'),
        ),
        isTrue,
      );
      expect(hoppinPasswordAlreadySet(StateError('no reset session')), isFalse);
    });
  });
}
