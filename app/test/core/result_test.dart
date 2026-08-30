import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';

void main() {
  group('Result', () {
    test('Ok carries a value', () {
      const r = Ok<int>(42);
      expect(r.isOk, isTrue);
      expect(r.valueOrNull, 42);
      expect(r.errorOrNull, isNull);
    });

    test('Err carries an ApiException', () {
      final r = Err<int>(ApiException('OFFER_EXPIRED', 'gone', 409));
      expect(r.isOk, isFalse);
      expect(r.valueOrNull, isNull);
      expect(r.errorOrNull!.code, 'OFFER_EXPIRED');
    });

    test('when branches on the variant', () {
      const ok = Ok<int>(1);
      final err = Err<int>(ApiException('INTERNAL', 'boom', 500));
      expect(ok.when(ok: (v) => 'v$v', err: (e) => 'e${e.code}'), 'v1');
      expect(err.when(ok: (v) => 'v$v', err: (e) => 'e${e.code}'), 'eINTERNAL');
    });
  });

  group('ApiException', () {
    test('marks transient codes retryable', () {
      expect(ApiException('INTERNAL', '', 500).isRetryable, isTrue);
      expect(ApiException('STORAGE_DISABLED', '', 503).isRetryable, isTrue);
      expect(ApiException('POSITION_UNAVAILABLE', '', 409).isRetryable, isTrue);
      expect(ApiException('NO_DRIVER_ASSIGNED', '', 409).isRetryable, isTrue);
    });

    test('marks state-dependent codes not retryable', () {
      expect(ApiException('OFFER_EXPIRED', '', 409).isRetryable, isFalse);
      expect(ApiException('ACCOUNT_SUSPENDED', '', 403).isRetryable, isFalse);
      expect(ApiException('VALIDATION_FAILED', '', 400).isRetryable, isFalse);
    });

    test('carries extra fields such as NOT_ELIGIBLE reason', () {
      final e = ApiException('NOT_ELIGIBLE', 'blocked', 403, fields: {
        'reason': 'DOCS_EXPIRED',
        'blocking_document_types': ['vehicle_insurance'],
      });
      expect(e.fields['reason'], 'DOCS_EXPIRED');
    });
  });
}
