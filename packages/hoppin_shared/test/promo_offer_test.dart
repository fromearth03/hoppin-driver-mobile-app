import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Catalogue contract acceptance: [PromoOffer] round-trips the row shape
/// `GET /promotions` serves and degrades safely on every field the server
/// documents as nullable.
void main() {
  group('PromoOffer', () {
    const percentJson = <String, dynamic>{
      'promo_code': 'AUTUMN20',
      'title': 'Autumn saver',
      'description': '20% off your next trip',
      'discount_type': 'percentage',
      'discount_value': 20,
      'max_discount_cap': 5.0,
      'min_ride_amount': 8.0,
      'new_users_only': false,
      'expires_at': '2026-09-30',
    };

    test('round-trips the documented catalogue row', () {
      final p = PromoOffer.fromJson(percentJson);
      expect(p.promoCode, 'AUTUMN20');
      expect(p.title, 'Autumn saver');
      expect(p.discountType, 'percentage');
      expect(p.discountValue, 20);
      expect(p.maxDiscountCap, 5.0);
      expect(p.minRideAmount, 8.0);
      expect(p.newUsersOnly, isFalse);
      expect(p.expiresAt, DateTime(2026, 9, 30));
    });

    test('a percentage offer headlines as "20% off", no trailing zeros', () {
      expect(PromoOffer.fromJson(percentJson).headline, '20% off');
    });

    test('a fixed-amount offer headlines in pounds', () {
      final json = Map<String, dynamic>.of(percentJson)
        ..['discount_type'] = 'fixed_amount'
        ..['discount_value'] = 5;
      expect(PromoOffer.fromJson(json).headline, '£5 off');
    });

    test('a fractional discount keeps its pence', () {
      final json = Map<String, dynamic>.of(percentJson)
        ..['discount_type'] = 'fixed_amount'
        ..['discount_value'] = 2.5;
      expect(PromoOffer.fromJson(json).headline, '£2.50 off');
    });

    test('an UNKNOWN discount type degrades to the code, never to "0% off"', () {
      // A server-side enum this build has not seen must not render as a zero
      // discount — that understates a real offer and reads as broken.
      final json = Map<String, dynamic>.of(percentJson)
        ..['discount_type'] = 'buy_one_get_one';
      expect(PromoOffer.fromJson(json).headline, 'AUTUMN20');
    });

    test('nullable columns tolerate null — cap, minimum and expiry', () {
      final json = Map<String, dynamic>.of(percentJson)
        ..['max_discount_cap'] = null
        ..['min_ride_amount'] = null
        ..['expires_at'] = null;
      final p = PromoOffer.fromJson(json);
      expect(p.maxDiscountCap, isNull);
      expect(p.minRideAmount, isNull);
      expect(p.expiresAt, isNull,
          reason: 'an open-ended offer has no expiry and must not invent one');
    });

    test('an unparseable expiry becomes null rather than throwing', () {
      final json = Map<String, dynamic>.of(percentJson)
        ..['expires_at'] = 'not-a-date';
      expect(PromoOffer.fromJson(json).expiresAt, isNull);
    });

    test('a blank title falls back to the headline, not to an empty row', () {
      final json = Map<String, dynamic>.of(percentJson)..['title'] = '';
      expect(PromoOffer.fromJson(json).displayTitle, '20% off');
    });

    test('a full timestamp expiry parses as well as a bare date', () {
      final json = Map<String, dynamic>.of(percentJson)
        ..['expires_at'] = '2026-09-30 23:59:59';
      expect(PromoOffer.fromJson(json).expiresAt, DateTime(2026, 9, 30, 23, 59, 59));
    });
  });
}
