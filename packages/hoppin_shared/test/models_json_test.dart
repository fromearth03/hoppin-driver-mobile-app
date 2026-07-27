import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Parses the sample payloads from DOCS/04-app-api-reference.md — if a JSON
/// key mapping drifts from the documented contract, these fail.
void main() {
  test('FareEstimate parses the documented /rides/estimate sample', () {
    final json = {
      'estimate': {
        'base': 2.50,
        'distance': 4.80,
        'time': 1.20,
        'service_fee': 0.50,
        'subtotal': 9.00,
        'multiplier': 1.0,
        'surge': 1.0,
        'gross': 9.00,
        'minimum': 5.00,
        'total': 9.00,
      },
      'distance_meters': 3900,
      'duration_seconds': 468,
      'vehicle_category_id': 'cat-1',
    };
    final est = FareEstimate.fromJson(json);
    expect(est.estimate.total, 9.00);
    expect(est.estimate.minimum, 5.00);
    expect(est.distanceMeters, 3900);
    expect(est.durationSeconds, 468);
  });

  test('Ride parses with null driver and unknown status safely', () {
    final json = {
      'id': 'ride-1',
      'rider_id': 'rider-1',
      'driver_id': null,
      'fare_id': 'fare-1',
      'ride_category': 'standard',
      'status': 'matching',
      'created_at': '2026-07-05T13:45:10Z',
    };
    final ride = Ride.fromJson(json);
    expect(ride.driverId, isNull);
    expect(ride.status, RideStatus.matching);

    final weird = Ride.fromJson({...json, 'status': 'brand_new_status'});
    expect(weird.status, RideStatus.unknown);
  });

  test('Receipt parses the documented pence sample', () {
    final json = {
      'ride_id': 'ride-1',
      'ride_category': 'standard',
      'fare_pence': 900,
      'waiting_pence': 0,
      'total_pence': 900,
      'platform_commission_pence': 180,
      'currency': 'GBP',
      'status': 'completed',
      'distance_miles': 2.4,
      'pickup_time': '2026-07-05T13:00:00Z',
      'dropoff_time': '2026-07-05T13:12:00Z',
      'provider_payment_id': 'pi_123',
    };
    final r = Receipt.fromJson(json);
    expect(r.totalPence, 900);
    expect(r.platformCommissionPence, 180);
    expect(r.distanceMiles, 2.4);
    expect(formatPence(r.totalPence), '£9.00');
  });

  test('RideOffer parses the documented offers sample', () {
    final json = {
      'offer_id': 'offer-1',
      'ride_id': 'ride-1',
      'pickup_lat': 52.58,
      'pickup_lng': -2.12,
      'dropoff_lat': 52.59,
      'dropoff_lng': -2.11,
      'fare': 9.0,
      'estimated_miles': 2.4,
      'expires_at': '2026-07-05T13:46:00Z',
      'offered_at': '2026-07-05T13:45:40Z',
    };
    final o = RideOffer.fromJson(json);
    expect(o.offerId, 'offer-1');
    expect(o.fare, 9.0);
    expect(o.expiresAt.isAfter(o.offeredAt), isTrue);
  });

  test('PromoResult parses and handles integer amounts', () {
    final json = {
      'promo_code': 'SUMMER10',
      'discount_type': 'percentage',
      'original_fare': 10, // servers may emit ints for whole pounds
      'discount_amount': 1.0,
      'new_fare': 9.0,
    };
    final p = PromoResult.fromJson(json);
    expect(p.originalFare, 10.0);
    expect(p.newFare, 9.0);
  });

  test('SavedLocation parses list-item shape (no user_id)', () {
    final s = SavedLocation.fromJson({
      'id': 'loc-1',
      'label': 'Home',
      'lat': 52.58,
      'lng': -2.12,
    });
    expect(s.userId, isNull);
    expect(s.label, 'Home');
  });

  test('SosEvent parses the documented shape', () {
    final e = SosEvent.fromJson({
      'id': 'sos-1',
      'ride_id': 'ride-1',
      'triggered_by': 'rider',
      'status': 'active',
      'lat': 52.58,
      'note': 'help',
      'created_at': '2026-07-05T13:00:00Z',
    });
    expect(e.status, 'active');
    expect(e.rideId, 'ride-1');
    expect(e.lng, isNull);
  });

  test('TicketThread parses ticket + messages envelope', () {
    final t = TicketThread.fromJson({
      'ticket': {'id': 't-1', 'subject': 'Lost item', 'status': 'open'},
      'messages': [
        {
          'id': 'm-1',
          'ticket_id': 't-1',
          'author_id': 'u-1',
          'is_staff': true,
          'body': 'We are on it',
          'created_at': '2026-07-05T13:00:00Z',
        },
      ],
    });
    expect(t.ticket.subject, 'Lost item');
    expect(t.messages.single.isStaff, isTrue);
  });

  test('PaymentMethod parses camelCase (Java service passthrough)', () {
    final pm = PaymentMethod.fromJson({
      'paymentMethodId': 'pm_1',
      'brand': 'visa',
      'last4': '4242',
      'expMonth': 12,
      'expYear': 2030,
      'isDefault': true,
    });
    expect(pm.last4, '4242');
    expect(pm.isDefault, isTrue);
  });

  test('Transaction parses pence amounts', () {
    final t = Transaction.fromJson({
      'id': 'txn-1',
      'ride_id': 'ride-1',
      'amount_pence': 900,
      'currency': 'GBP',
      'status': 'captured',
      'provider': 'stripe',
      'created_at': '2026-07-05T13:12:00Z',
    });
    expect(t.amountPence, 900);
    expect(formatPence(t.amountPence), '£9.00');
  });

  test('RideMessage parses chat shape', () {
    final m = RideMessage.fromJson({
      'id': 'msg-1',
      'ride_id': 'ride-1',
      'sender_id': 'u-1',
      'sender_role': 'rider',
      'body': 'On my way down',
      'created_at': '2026-07-05T13:05:00Z',
    });
    expect(m.senderRole, 'rider');
    expect(m.body, 'On my way down');
  });

  test('EmergencyContact parses with default auto-share', () {
    final c = EmergencyContact.fromJson({
      'id': 'ec-1',
      'contact_name': 'Sam',
      'phone_number': '+447700900000',
    });
    expect(c.autoShareNightTrips, isFalse);
  });
}
