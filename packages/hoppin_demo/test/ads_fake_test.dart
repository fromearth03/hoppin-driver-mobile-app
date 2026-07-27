import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 exports the Override type from misc.dart, not the main barrel.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Ads demo acceptance: [FakeAdsRepository] serves two seeded,
/// Wolverhampton-plausible banners audience-stamped per composition (the
/// live endpoint derives audience from the JWT role — rider app sees
/// `riders`, driver app sees `drivers`), and engagement reporting lands in
/// an inspectable in-memory log instead of the network.
void main() {
  DemoWorld riderWorld() => DemoWorld.riderScenario(
        seed: DemoSeed.seed,
        store: InMemorySnapshotStore(),
      )..restoreOrSeed();

  DemoWorld driverWorld() => DemoWorld.driverScenario(
        seed: DemoSeed.seed,
        store: InMemorySnapshotStore(),
      )..restoreOrSeed();

  group('seeded banners', () {
    test('serves exactly two active Wolverhampton banners', () async {
      final ads = await FakeAdsRepository(audience: 'riders').activeAds();

      expect(ads, hasLength(2));
      expect(ads.map((a) => a.id).toSet(), hasLength(2),
          reason: 'each banner must carry a distinct id');
      for (final ad in ads) {
        expect(ad.isActive, isTrue,
            reason: 'the live list only ever serves active banners');
        expect(ad.title, isNotEmpty);
        expect(ad.audience, 'riders');
      }
    });

    test('audience follows the composition — drivers see driver banners',
        () async {
      final ads = await FakeAdsRepository(audience: 'drivers').activeAds();
      expect(ads.map((a) => a.audience), everyElement('drivers'));
    });
  });

  group('engagement log', () {
    test('impressions and clicks record in order, never throwing', () async {
      final ads = FakeAdsRepository(audience: 'riders');
      final banner = (await ads.activeAds()).first;

      await ads.reportImpression(banner.id);
      await ads.reportClick(banner.id);
      // Best-effort contract: an unknown id records too — analytics must
      // never break the UI, so nothing validates or throws here.
      await ads.reportImpression('ad-gone');

      expect(ads.engagementLog, [
        'impression:${banner.id}',
        'click:${banner.id}',
        'impression:ad-gone',
      ]);
    });
  });

  group('composition wiring', () {
    ProviderContainer containerWith(List<Override> overrides) {
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      return container;
    }

    test('rider composition resolves the ads fake with the riders audience',
        () async {
      final container = containerWith(riderDemoOverrides(riderWorld()));
      final repo = container.read(adsRepositoryProvider);
      expect(repo, isA<FakeAdsRepository>());
      final ads = await repo.activeAds();
      expect(ads.map((a) => a.audience), everyElement('riders'));
    });

    test('driver composition resolves the ads fake with the drivers audience',
        () async {
      final container = containerWith(driverDemoOverrides(driverWorld()));
      final repo = container.read(adsRepositoryProvider);
      expect(repo, isA<FakeAdsRepository>());
      final ads = await repo.activeAds();
      expect(ads.map((a) => a.audience), everyElement('drivers'));
    });
  });
}
