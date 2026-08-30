import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/push/push_payload.dart';

void main() {
  test('parses a ride offer push', () {
    final p = PushPayload.parse({
      'type': 'ride_offer',
      'ride_id': 'r1',
      'offer_id': 'o1',
      'deep_link': '/offer',
      'expiresIn': '60',
      'fare': '20.15',
    });

    expect(p!.type, PushType.rideOffer);
    expect(p.rideId, 'r1');
    expect(p.offerId, 'o1');
  });

  test('prefers snake_case when both cases are present', () {
    final p = PushPayload.parse({
      'type': 'ride_offer',
      'ride_id': 'snake',
      'rideId': 'camel',
    });

    expect(p!.rideId, 'snake');
  });

  test('parses a compliance appeal decision', () {
    final p = PushPayload.parse({
      'type': 'compliance_appeal',
      'appeal_id': 'a1',
      'decision': 'approved',
    });

    expect(p!.type, PushType.complianceAppeal);
  });

  test('an unknown type parses as other rather than throwing', () {
    final p = PushPayload.parse({'type': 'something_new'});
    expect(p!.type, PushType.other);
  });

  test('returns null for a payload with no type', () {
    expect(PushPayload.parse({'body': 'hello'}), isNull);
  });

  test('exposes no fare or money field at all', () {
    // The push is a wake-up, not data. If the payload's fare were readable
    // here, a screen could render it and disagree with the real offer.
    final p = PushPayload.parse({'type': 'ride_offer', 'fare': '20.15'});
    expect(p.toString().contains('20.15'), isFalse);
  });
}
