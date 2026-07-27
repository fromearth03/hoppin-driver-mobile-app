import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// NOTIF-01 — the compile-time FCM gate.
///
/// `Env.fcmConfigured` is the guard that keeps `Firebase.initializeApp()` from
/// ever being reached in a build with no Firebase project. On web an
/// unconfigured init throws a bare `TypeError` (NOT a `FirebaseException`), so
/// an `on FirebaseException catch` would let the app white-screen. The GUARD is
/// what we test — never the exception type.
void main() {
  group('NOTIF-01: Env.fcmConfigured', () {
    test('is FALSE with no dart-defines — today\'s reality', () {
      expect(
        Env.fcmConfigured,
        isFalse,
        reason:
            'No FCM dart-defines are passed to `flutter test`, so the guard '
            'must be false. If this ever goes true by accident, main.dart '
            'would call Firebase.initializeApp() and the web build would '
            'white-screen.',
      );
    });

    test('the five FCM defines are all empty in this build', () {
      expect(Env.fcmApiKey, isEmpty, reason: 'No FCM_API_KEY define.');
      expect(Env.fcmProjectId, isEmpty, reason: 'No FCM_PROJECT_ID define.');
      expect(Env.fcmSenderId, isEmpty, reason: 'No FCM_SENDER_ID define.');
      expect(Env.fcmAppId, isEmpty, reason: 'No FCM_APP_ID define.');
      expect(Env.fcmVapidKey, isEmpty, reason: 'No FCM_VAPID_KEY define.');
    });
  });

  group('NOTIF-01: FCM absence is a SOFT gate, never a boot failure', () {
    test('assertConfigured() polices SUPABASE only — it never mentions FCM',
        () {
      // Under `flutter test` no dart-defines are passed, so the SUPABASE assert
      // fires. What matters here is WHAT it polices: if FCM were ever folded
      // into this assert, an unconfigured FCM build would become a BOOT
      // FAILURE — but push is ADDITIVE over the 3s poll floor and must never
      // be able to stop the app starting.
      Object? thrown;
      try {
        Env.assertConfigured();
      } on Object catch (e) {
        thrown = e;
      }

      expect(
        thrown,
        isA<AssertionError>(),
        reason: 'No SUPABASE defines under `flutter test` → the assert fires.',
      );
      final message = thrown.toString();
      expect(
        message,
        contains('SUPABASE'),
        reason: 'The assert exists to police Supabase.',
      );
      expect(
        message.toUpperCase(),
        isNot(contains('FCM')),
        reason:
            'FCM must NEVER be part of assertConfigured. Its absence is a '
            'soft, honest GATED state, not a boot failure.',
      );
    });
  });
}
