import 'package:hoppin_shared/hoppin_shared.dart';

import '../seed/demo_seed.dart';

/// The in-app ads surface — two seeded Wolverhampton-plausible banners,
/// audience-stamped per composition (the live `GET /ads` derives audience
/// from the JWT role: rider app → `riders`, driver app → `drivers`).
///
/// Engagement reporting appends to [engagementLog] instead of the network —
/// inspectable in tests, and honoring the live best-effort contract: it
/// never validates and never throws (analytics must never break the UI).
class FakeAdsRepository implements AdsRepository {
  FakeAdsRepository({required this.audience});

  /// The audience this composition's banners carry: `riders` or `drivers`.
  final String audience;

  final List<String> _engagementLog = [];

  /// Every impression/click recorded this session, in call order, as
  /// `impression:<adId>` / `click:<adId>` entries.
  List<String> get engagementLog => List.unmodifiable(_engagementLog);

  /// Both banners run a four-week flight straddling the seeded anchor, so
  /// they are live "today" by construction; all timestamps derive from
  /// [DemoSeed.anchor] — never the wall clock.
  static final DateTime _flightStart =
      DemoSeed.anchor.subtract(const Duration(days: 7));
  static final DateTime _flightEnd =
      DemoSeed.anchor.add(const Duration(days: 21));

  late final List<Ad> _seededAds = List.unmodifiable([
    Ad(
      id: 'e2000000-0000-4000-8000-000000000001',
      title: 'Wolverhampton Grand Theatre',
      body: 'Evening shows from £15 — Lichfield Street, doors 7pm.',
      targetUrl: 'https://grandtheatre.co.uk',
      audience: audience,
      startsAt: _flightStart,
      endsAt: _flightEnd,
      createdAt: _flightStart,
    ),
    Ad(
      id: 'e2000000-0000-4000-8000-000000000002',
      title: 'Late-night Fridays at Bentley Bridge',
      body: 'Shops and restaurants open until 10pm every Friday.',
      targetUrl: 'https://bentleybridge.co.uk',
      audience: audience,
      startsAt: _flightStart,
      endsAt: _flightEnd,
      createdAt: _flightStart,
    ),
  ]);

  @override
  Future<List<Ad>> activeAds() async => _seededAds;

  @override
  Future<void> reportImpression(String adId) async {
    _engagementLog.add('impression:$adId');
  }

  @override
  Future<void> reportClick(String adId) async {
    _engagementLog.add('click:$adId');
  }
}
