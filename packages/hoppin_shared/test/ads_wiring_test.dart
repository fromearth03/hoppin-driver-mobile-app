import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ads wiring acceptance: [Ad] and [AdsRepository] are part of the public
/// barrel (this file imports `package:hoppin_shared` alone), the model
/// round-trips the documented `GET /ads` item shape, and the composition
/// root exposes [adsRepositoryProvider] over the shared [ApiClient].
void main() {
  group('Ad', () {
    const fullJson = <String, dynamic>{
      'id': 'ad-1',
      'title': 'Wolverhampton Grand Theatre',
      'body': 'Evening shows from £15.',
      'image_url': 'https://cdn.hoppin.uk/ads/grand.png',
      'target_url': 'https://grandtheatre.co.uk',
      'audience': 'riders',
      'is_active': true,
      'starts_at': '2026-06-23T09:30:00.000',
      'ends_at': '2026-07-21T09:30:00.000',
      'created_at': '2026-06-23T09:30:00.000',
    };

    test('round-trips the documented /ads item shape', () {
      final ad = Ad.fromJson(fullJson);
      expect(ad.id, 'ad-1');
      expect(ad.title, 'Wolverhampton Grand Theatre');
      expect(ad.audience, 'riders');
      expect(ad.isActive, isTrue);
      expect(ad.targetUrl, 'https://grandtheatre.co.uk');
      expect(jsonDecode(jsonEncode(ad.toJson())), fullJson);
    });

    test('optional fields tolerate a minimal banner', () {
      final ad = Ad.fromJson(const {'id': 'ad-2', 'title': 'Ride with Hoppin'});
      expect(ad.body, isNull);
      expect(ad.imageUrl, isNull);
      expect(ad.targetUrl, isNull);
      expect(ad.isActive, isTrue,
          reason: 'the live list only ever serves active banners');
      final reparsed = Ad.fromJson(
        jsonDecode(jsonEncode(ad.toJson())) as Map<String, dynamic>,
      );
      expect(reparsed, ad);
    });
  });

  group('composition root', () {
    test('adsRepositoryProvider builds an AdsRepository over the ApiClient',
        () {
      final api = ApiClient(
        auth: AuthService(
          SupabaseClient('http://localhost:54321', 'publishable-key'),
        ),
      );
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      expect(container.read(adsRepositoryProvider), isA<AdsRepository>());
    });
  });
}
