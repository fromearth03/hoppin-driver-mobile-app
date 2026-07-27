import 'dart:math' as math;

import 'package:hoppin_shared/hoppin_shared.dart';

import 'demo_seed.dart';

// DOCS/04 pricing shape (POST /rides/estimate):
//   subtotal = base + distance + time + service_fee
//   gross    = subtotal x multiplier x surge
//   total    = max(gross, minimum)
const double _basePounds = 2.50;
const double _perMilePounds = 1.10;
const double _perMinutePounds = 0.15;
const double _serviceFeePounds = 0.50;
const double _minimumPounds = 5.00;
const double _multiplier = 1.0;
const double _surge = 1.0;

/// Straight-line to road-distance correction.
const double _roadFactor = 1.3;

/// Average urban speed used for duration estimates.
const double _averageMph = 18.0;

const double _metersPerMile = 1609.344;
const double _earthRadiusMeters = 6371000.0;

/// The fraction HOPPIN20 takes off a fare.
const double _hoppin20Fraction = 0.20;

double _round2(double value) => (value * 100).roundToDouble() / 100;

double _degToRad(double degrees) => degrees * math.pi / 180;

/// Great-circle distance in meters.
double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(a.toDouble()));
}

double _roadMetersBetween(
  double pickupLat,
  double pickupLng,
  double dropoffLat,
  double dropoffLng,
) =>
    _haversineMeters(pickupLat, pickupLng, dropoffLat, dropoffLng) *
    _roadFactor;

/// Pure fare quote for a route — identical inputs always produce identical
/// values. Every money figure is pounds rounded to 2dp.
Quote quoteBetween({
  required double pickupLat,
  required double pickupLng,
  required double dropoffLat,
  required double dropoffLng,
}) {
  final meters =
      _roadMetersBetween(pickupLat, pickupLng, dropoffLat, dropoffLng);
  final miles = meters / _metersPerMile;
  final minutes = miles / _averageMph * 60;

  final distanceCharge = _round2(miles * _perMilePounds);
  final timeCharge = _round2(minutes * _perMinutePounds);
  final subtotal =
      _round2(_basePounds + distanceCharge + timeCharge + _serviceFeePounds);
  final gross = _round2(subtotal * _multiplier * _surge);
  final total = _round2(math.max(gross, _minimumPounds));

  return Quote(
    base: _basePounds,
    distance: distanceCharge,
    time: timeCharge,
    serviceFee: _serviceFeePounds,
    subtotal: subtotal,
    multiplier: _multiplier,
    surge: _surge,
    gross: gross,
    minimum: _minimumPounds,
    total: total,
  );
}

/// Pure `POST /rides/estimate` response for a route.
FareEstimate estimateBetween({
  required double pickupLat,
  required double pickupLng,
  required double dropoffLat,
  required double dropoffLng,
}) {
  final meters =
      _roadMetersBetween(pickupLat, pickupLng, dropoffLat, dropoffLng);
  final seconds = meters / _metersPerMile / _averageMph * 3600;
  return FareEstimate(
    estimate: quoteBetween(
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
    ),
    distanceMeters: meters.round(),
    durationSeconds: seconds.round(),
  );
}

/// Applies a promo code to a fare in pounds. Only [DemoSeed.promoCode]
/// (HOPPIN20, 20% percentage type) exists in the demo world; any other code
/// returns null so the fake repository can raise the PROMO_NOT_FOUND shape.
PromoResult? promoResultFor({
  required String code,
  required double originalFare,
}) {
  if (code.trim().toUpperCase() != DemoSeed.promoCode) return null;
  final discount = _round2(originalFare * _hoppin20Fraction);
  return PromoResult(
    promoCode: DemoSeed.promoCode,
    discountType: 'percentage',
    originalFare: _round2(originalFare),
    discountAmount: discount,
    newFare: _round2(originalFare - discount),
  );
}
