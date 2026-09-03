import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/api/error_codes.dart';

void main() {
  group('errorCopy', () {
    test('maps known driver-reachable codes', () {
      expect(errorCopy(ApiException('OFFER_EXPIRED', '', 409)),
          'This offer has lapsed.');
      expect(errorCopy(ApiException('ACCOUNT_SUSPENDED', '', 403)),
          'Your account is suspended. Please contact support.');
      expect(errorCopy(ApiException('ILLEGAL_TRANSITION', '', 409)),
          "This ride isn't in a state that allows that. Refreshing now.");
    });

    test('falls back generically for an unlisted code', () {
      expect(errorCopy(ApiException('SOME_NEW_CODE', 'raw server text', 500)),
          'Something went wrong. Please try again.');
    });

    test('never surfaces the raw server message', () {
      final copy = errorCopy(ApiException('WHATEVER', 'sql: no rows', 500));
      expect(copy.contains('sql'), isFalse);
    });

    test('NO_SHOW_TOO_EARLY reports the remaining wait', () {
      final e = ApiException('NO_SHOW_TOO_EARLY', '', 400,
          fields: {'seconds_remaining': 120});
      expect(errorCopy(e), 'You can report a no-show in 2 min.');
    });
  });

  group('notEligibleCopy', () {
    test('gives each blocked reason its own title, body and action', () {
      final docs = notEligibleCopy('DOCS_EXPIRED');
      expect(docs.title, 'Document expired');
      expect(docs.action, BlockedAction.openDocuments);

      final review = notEligibleCopy('DOCS_PENDING_REVIEW');
      expect(review.action, BlockedAction.none);

      final susp = notEligibleCopy('SUSPENDED');
      expect(susp.action, BlockedAction.contactSupport);

      final vehicle = notEligibleCopy('NO_VEHICLE');
      expect(vehicle.action, BlockedAction.registerVehicle);
    });

    test('covers all eleven tokens', () {
      const tokens = [
        'SUSPENDED',
        'RESTRICTED',
        'DELETION_REQUESTED',
        'DOCS_MISSING',
        'DOCS_PENDING_REVIEW',
        'DOCS_REJECTED',
        'DOCS_EXPIRED',
        'NO_VEHICLE',
        'DEVICE_BLACKLISTED',
        'PAYOUT_NOT_READY',
        'UNKNOWN',
      ];
      for (final t in tokens) {
        expect(notEligibleCopy(t).title, isNotEmpty,
            reason: 'missing copy for $t');
      }
    });

    test('an unrecognised token degrades to the UNKNOWN copy', () {
      expect(notEligibleCopy('SOMETHING_ELSE').title,
          notEligibleCopy('UNKNOWN').title);
    });
  });

  group('a stale session says so', () {
    // 🔴 THE MOST COMMON 401 THERE IS. The service answers `AUTH_REQUIRED`
    // for an absent, expired or rejected token — verified against
    // api.hoppin.tech, which returns {"code":"AUTH_REQUIRED"} on every
    // guarded route. It had no copy, so every screen in a stale session fell
    // through to the generic fallback: a driver was told the app was broken
    // when the fix was to sign in again.
    test('AUTH_REQUIRED names the cause and the remedy', () {
      final copy = errorCopy(ApiException('AUTH_REQUIRED', 'unauthorized', 401));

      expect(copy, isNot(contains('Something went wrong')),
          reason: 'the generic fallback names no cause and no fix');
      expect(copy.toLowerCase(), contains('sign in'),
          reason: 'the remedy is the point — retrying forever is not');
    });
  });
}
