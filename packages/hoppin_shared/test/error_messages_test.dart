import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('friendlyErrorMessage', () {
    test('maps invalid_credentials', () {
      expect(
        friendlyErrorMessage(
          const AuthException('bad', code: 'invalid_credentials'),
        ),
        'Incorrect email or password.',
      );
    });

    test('maps user_already_exists', () {
      expect(
        friendlyErrorMessage(
          const AuthException('exists', code: 'user_already_exists'),
        ),
        'An account with this email already exists — try signing in.',
      );
    });

    test('falls back to the AuthException message for unknown codes', () {
      expect(
        friendlyErrorMessage(const AuthException('Custom server message')),
        'Custom server message',
      );
    });

    test('uses ApiException.message (ride-service envelope)', () {
      expect(
        friendlyErrorMessage(
          const ApiException(
            statusCode: 409,
            message: 'You already have an active trip',
            code: 'ACTIVE_TRIP_EXISTS',
          ),
        ),
        'You already have an active trip',
      );
    });

    test('network-flavoured ApiException gets the connection message', () {
      expect(
        friendlyErrorMessage(
          const ApiException(
            statusCode: 0,
            message: 'connection refused',
            code: 'NETWORK_ERROR',
          ),
        ),
        contains('connection'),
      );
    });

    test('generic fallback for unknown error types', () {
      expect(
        friendlyErrorMessage(StateError('boom')),
        'Something went wrong. Please try again.',
      );
    });
  });
}
