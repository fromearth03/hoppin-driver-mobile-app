import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Driver compliance-documents demo acceptance: [FakeDriverRepository]
/// serves a seeded document wallet for Gurpreet (insurance verified, MOT
/// verified but expiring in 20 virtual days, DVLA licence verified) and
/// simulates the presigned two-step upload entirely in memory — a confirm
/// replaces the same-type document as `pending_review`, exactly the live
/// contract, with zero storage calls.
void main() {
  DemoWorld driverWorld() => DemoWorld.driverScenario(
        seed: DemoSeed.seed,
        store: InMemorySnapshotStore(),
      )..restoreOrSeed();

  /// Resolves a fake's Future synchronously under fake time — every fake
  /// wraps a synchronous read, so a microtask flush must complete it.
  T resolve<T>(FakeAsync async, Future<T> future) {
    late T value;
    var done = false;
    future.then((v) {
      value = v;
      done = true;
    });
    async.flushMicrotasks();
    expect(done, isTrue, reason: 'fakes must not need real time to complete');
    return value;
  }

  /// The error a fake's Future completes with, or null when it succeeds.
  Object? errorOf(FakeAsync async, Future<void> Function() call) {
    Object? error;
    call().then((_) {}, onError: (Object e) {
      error = e;
    });
    async.flushMicrotasks();
    return error;
  }

  Matcher validationFailed() => isA<ApiException>()
      .having((e) => e.statusCode, 'statusCode', 400)
      .having((e) => e.code, 'code', 'VALIDATION_FAILED');

  group('seeded document wallet', () {
    test('serves three verified documents newest-first', () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        final docs = resolve(async, driver.documents());
        expect(
          docs.map((d) => d.documentType).toList(),
          ['insurance_policy', 'dvla_license', 'mot_certificate'],
          reason: 'the list is newest-first, like the live read',
        );
        expect(docs.map((d) => d.verificationStatus), everyElement('verified'));
      });
    });

    test('the MOT certificate expires 20 virtual days out — the renewal beat',
        () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        final mot = resolve(async, driver.documents())
            .singleWhere((d) => d.documentType == 'mot_certificate');
        expect(
          mot.expiresAt,
          DemoSeed.anchor.add(const Duration(days: 20)),
        );
      });
    });

    test('the DVLA licence carries no expiry — the nullable path', () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        final dvla = resolve(async, driver.documents())
            .singleWhere((d) => d.documentType == 'dvla_license');
        expect(dvla.expiresAt, isNull);
      });
    });
  });

  group('documentUploadUrl', () {
    test('issues a presigned slot shaped like the live response', () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        final slot = resolve(
          async,
          driver.documentUploadUrl(
            documentType: 'mot_certificate',
            contentType: 'application/pdf',
          ),
        );
        expect(
          slot.key,
          startsWith('driver-docs/${DemoSeed.driverId}/mot_certificate/'),
          reason: 'the live key prefix is scoped to the calling driver',
        );
        expect(slot.uploadUrl, contains(slot.key));
        expect(slot.contentType, 'application/pdf');
        expect(slot.maxBytes, 10485760);
        // The virtual clock boots at the anchor; the URL TTL is 5 minutes.
        expect(
          slot.urlExpiresAt,
          DemoSeed.anchor.add(const Duration(minutes: 5)),
        );
      });
    });

    test('rejects an unknown document type with VALIDATION_FAILED', () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        final error = errorOf(
          async,
          () => driver.documentUploadUrl(
            documentType: 'passport',
            contentType: 'application/pdf',
          ),
        );
        expect(error, validationFailed());
      });
    });

    test('rejects an unsupported content type with VALIDATION_FAILED', () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        final error = errorOf(
          async,
          () => driver.documentUploadUrl(
            documentType: 'mot_certificate',
            contentType: 'image/gif',
          ),
        );
        expect(error, validationFailed());
      });
    });
  });

  group('confirmDocument', () {
    test('replaces the same-type document as pending_review at the head', () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());
        final newExpiry = DemoSeed.anchor.add(const Duration(days: 385));

        final slot = resolve(
          async,
          driver.documentUploadUrl(
            documentType: 'mot_certificate',
            contentType: 'application/pdf',
          ),
        );
        // The PUT of the raw bytes is simulated — no storage in the demo.
        final confirmed = resolve(
          async,
          driver.confirmDocument(
            documentType: 'mot_certificate',
            key: slot.key,
            expiresAt: newExpiry,
          ),
        );
        expect(confirmed.verificationStatus, 'pending_review');
        expect(confirmed.documentType, 'mot_certificate');
        expect(confirmed.expiresAt, newExpiry);

        final docs = resolve(async, driver.documents());
        expect(docs, hasLength(3),
            reason: 'a confirm replaces the current document of that type');
        expect(docs.first, confirmed,
            reason: 'the fresh upload sits newest-first');
        expect(
          docs.where((d) => d.documentType == 'mot_certificate'),
          hasLength(1),
        );
      });
    });

    test('adds a brand-new type without touching the others', () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        final slot = resolve(
          async,
          driver.documentUploadUrl(
            documentType: 'wolverhampton_taxi_badge',
            contentType: 'image/jpeg',
          ),
        );
        final confirmed = resolve(
          async,
          driver.confirmDocument(
            documentType: 'wolverhampton_taxi_badge',
            key: slot.key,
          ),
        );
        expect(confirmed.verificationStatus, 'pending_review');
        expect(confirmed.expiresAt, isNull);

        final docs = resolve(async, driver.documents());
        expect(docs, hasLength(4));
        expect(docs.first, confirmed);
      });
    });

    test("rejects a key outside the caller's prefix with VALIDATION_FAILED",
        () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        final error = errorOf(
          async,
          () => driver.confirmDocument(
            documentType: 'mot_certificate',
            key: 'driver-docs/somebody-else/mot_certificate/1',
          ),
        );
        expect(error, validationFailed());
      });
    });
  });
}
