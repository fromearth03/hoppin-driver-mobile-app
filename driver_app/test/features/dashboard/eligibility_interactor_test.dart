import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/dashboard/eligibility_builder.dart';
import 'package:hoppin_driver/features/dashboard/eligibility_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Interactor unit layer (riblet testing contract, DOCS/05): the five buckets,
/// the null skip, the failed-read ignorance, and the un-guessed 403 — all off
/// an INJECTED clock and a recording repository fake.
void main() {
  final now = DateTime.utc(2026, 7, 14, 9);

  DriverDocument doc(String type, {DateTime? expiresAt}) => DriverDocument(
        id: 'doc-$type',
        documentType: type,
        verificationStatus: 'approved',
        uploadedAt: now.subtract(const Duration(days: 90)),
        expiresAt: expiresAt,
      );

  Future<EligibilityState> ladderFor(
    List<DriverDocument> docs, {
    Object? error,
  }) async {
    final container = ProviderContainer(overrides: [
      driverRepositoryProvider.overrideWithValue(
        _StubDriverRepo(documentsResult: docs, documentsError: error),
      ),
      nowProvider.overrideWithValue(() => now),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(eligibilityInteractorProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(eligibilityInteractorProvider.notifier).refresh();
    return container.read(eligibilityInteractorProvider);
  }

  group('the five buckets, off the SERVER\'S real expires_at', () {
    test('>30d out: no rung at all — we do not nag', () async {
      final s = await ladderFor([
        doc('mot_certificate', expiresAt: now.add(const Duration(days: 45))),
      ]);
      expect(s.phase, EligibilityPhase.known);
      expect(s.expiries, isEmpty);
      expect(s.blocksGoOnline, isFalse);
    });

    test('<=30d: informational, and NOT blocking', () async {
      for (final days in [30, 8]) {
        final s = await ladderFor([
          doc('mot_certificate', expiresAt: now.add(Duration(days: days))),
        ]);
        expect(s.expiries.single.rung, ExpiryRung.informational,
            reason: 'T-${days}d');
        expect(s.blocksGoOnline, isFalse);
      }
    });

    test('<=7d: prominent, and NOT blocking', () async {
      for (final days in [7, 2]) {
        final s = await ladderFor([
          doc('insurance_policy', expiresAt: now.add(Duration(days: days))),
        ]);
        expect(s.expiries.single.rung, ExpiryRung.prominent,
            reason: 'T-${days}d');
        expect(s.blocksGoOnline, isFalse);
      }
    });

    test('<=1d: lastDay — loud, and STILL not blocking', () async {
      // 🔴 They can legally work today. Taking that day away from them costs a
      // real driver a real shift's earnings for no reason at all.
      for (final hours in [24, 6, 1]) {
        final s = await ladderFor([
          doc('mot_certificate', expiresAt: now.add(Duration(hours: hours))),
        ]);
        expect(s.expiries.single.rung, ExpiryRung.lastDay,
            reason: 'T-${hours}h');
        expect(s.blocksGoOnline, isFalse);
      }
    });

    test('past the server\'s date: expired — the ONLY rung that blocks',
        () async {
      final s = await ladderFor([
        doc('mot_certificate',
            expiresAt: now.subtract(const Duration(days: 1))),
      ]);
      expect(s.expiries.single.rung, ExpiryRung.expired);
      expect(s.blocksGoOnline, isTrue);
      expect(s.expiredDocuments.single.label, 'MOT certificate',
          reason: 'the rung must be able to NAME it');
    });

    test('rounds TOWARD the driver: 11 hours away is lastDay, not expired',
        () async {
      final s = await ladderFor([
        doc('mot_certificate', expiresAt: now.add(const Duration(hours: 11))),
      ]);
      expect(s.expiries.single.rung, ExpiryRung.lastDay);
      expect(s.blocksGoOnline, isFalse,
          reason: 'ambiguity favours their right to work');
    });
  });

  test('🔴 a NULL expires_at is SKIPPED ENTIRELY — no rung, never blocks',
      () async {
    // Null means *this document does not expire, or the server did not tell us
    // when*. It is NOT "expires today" and it is NOT "expired". An off-by-one
    // here disables a working driver's GO button, forever, for a background
    // check that was never going to expire.
    final s = await ladderFor([
      doc('nr3s_background_check'),
      doc('right_to_work'),
    ]);
    expect(s.phase, EligibilityPhase.known);
    expect(s.expiries, isEmpty);
    expect(s.blocksGoOnline, isFalse);
  });

  test('worst first: the expired document leads, and every other one stays',
      () async {
    final s = await ladderFor([
      doc('insurance_policy', expiresAt: now.add(const Duration(days: 20))),
      doc('mot_certificate',
          expiresAt: now.subtract(const Duration(days: 3))),
    ]);
    expect(s.expiries.first.rung, ExpiryRung.expired);
    expect(s.expiries.length, 2,
        reason: 'tell them everything you know, ONCE — a driver fixing their '
            'MOT must not discover the insurance only on the next tap');
    expect(s.blocksGoOnline, isTrue);
  });

  test('🔴 a THROWN documents() read is IGNORANCE, not ineligibility',
      () async {
    final s = await ladderFor(
      const [],
      error: const ApiException(statusCode: 500, message: 'boom'),
    );
    expect(s.phase, EligibilityPhase.unknown);
    expect(s.expiries, isEmpty);
    expect(s.blocksGoOnline, isFalse,
        reason: '🔴 a failed read must NEVER disable a driver\'s ability to '
            'earn — the server re-checks at go-online and is the authority');
  });

  group('403 NOT_ELIGIBLE — the reason is the server\'s, or it is null',
      () {
    test('a server message is stored VERBATIM', () async {
      final container = ProviderContainer(overrides: [
        driverRepositoryProvider.overrideWithValue(_StubDriverRepo()),
        nowProvider.overrideWithValue(() => now),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(eligibilityInteractorProvider, (_, _) {});
      addTearDown(sub.close);

      const words = 'Your taxi badge has been suspended pending review.';
      container
          .read(eligibilityInteractorProvider.notifier)
          .onNotEligible(words);

      final s = container.read(eligibilityInteractorProvider);
      expect(s.phase, EligibilityPhase.notEligible);
      expect(s.notEligibleReason, words,
          reason: 'unmodified, un-prettified, un-shortened');
    });

    test('🔴 no message → NULL. NEVER a fallback sentence', () async {
      final container = ProviderContainer(overrides: [
        driverRepositoryProvider.overrideWithValue(_StubDriverRepo()),
        nowProvider.overrideWithValue(() => now),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(eligibilityInteractorProvider, (_, _) {});
      addTearDown(sub.close);

      final interactor =
          container.read(eligibilityInteractorProvider.notifier);

      for (final message in [null, '', '   ']) {
        interactor.onNotEligible(message);
        final s = container.read(eligibilityInteractorProvider);
        expect(s.phase, EligibilityPhase.notEligible);
        expect(s.notEligibleReason, isNull,
            reason: '🔴 the app does not know what NOT_ELIGIBLE meant — '
                'compliance, restriction or suspension — and it must SAY so, '
                'not invent one');
      }
    });
  });

  test('🔴 a refresh NEVER overturns the server\'s own refusal', () async {
    // A clean documents read is NOT evidence the server would now let them in.
    // NOT_ELIGIBLE also covers RESTRICTION and SUSPENSION, and neither of those
    // shows up in `GET /drivers/me/documents` at all. Clearing the refusal on a
    // clean read would tell a SUSPENDED driver everything is fine — the same
    // guess this entire riblet exists to refuse. Only the SERVER may lift its
    // own refusal, with a 200 on the next GO.
    final container = ProviderContainer(overrides: [
      driverRepositoryProvider.overrideWithValue(_StubDriverRepo()),
      nowProvider.overrideWithValue(() => now),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(eligibilityInteractorProvider, (_, _) {});
    addTearDown(sub.close);
    final interactor = container.read(eligibilityInteractorProvider.notifier);

    interactor.onNotEligible(null);
    await interactor.refresh(); // a perfectly clean read: zero documents
    expect(container.read(eligibilityInteractorProvider).phase,
        EligibilityPhase.notEligible,
        reason: '🔴 the app does not get to un-refuse a driver the server '
            'refused');

    // The 200 does lift it — and only the 200.
    interactor.onEligible();
    final s = container.read(eligibilityInteractorProvider);
    expect(s.phase, EligibilityPhase.known);
    expect(s.notEligibleReason, isNull);
  });

  test('the interactor carries NO driver-facing copy at all — a source grep '
      'proves it', () {
    // 🔴 THE GUARD ON THE GUARD. Any string mapped from NOT_ELIGIBLE is a
    // defect; a fallback sentence smuggled into the interactor would satisfy
    // every state assertion above while still lying on the driver's screen.
    //
    // So the assertion is stronger than a word list: the interactor holds NO
    // string literal a human could read. `notEligibleReason` is either the
    // SERVER'S sentence or null, and there is nowhere else for a sentence to
    // hide.
    final code = File('lib/features/dashboard/eligibility_interactor.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    final literals = RegExp("'([^']*)'").allMatches(code).map((m) => m[1]!);
    for (final literal in literals) {
      // A prose sentence is the tell: two or more words with a space in it.
      expect(literal.trim().contains(' '), isFalse,
          reason: '🔴 "$literal" is driver-facing prose inside the interactor. '
              'The ONLY reason the app may show for a 403 NOT_ELIGIBLE is the '
              "SERVER'S own message — anything else is a guess at whether it "
              'meant compliance, restriction or suspension.');
    }
  });

  test('kDriverDocumentLabels covers EVERY document type the backend serves',
      () {
    // A type the backend serves and this map does not know would degrade to its
    // raw `snake_case` key on the driver's home screen — which names nothing.
    expect(
      kDriverDocumentLabels.keys.toSet(),
      DriverRepository.documentTypes.toSet(),
    );
  });
}

/// Drives the two BOUND driver reads this lane cares about, and nothing else.
class _StubDriverRepo implements DriverRepository {
  _StubDriverRepo({
    this.documentsResult = const [],
    this.documentsError,
  });

  final List<DriverDocument> documentsResult;
  final Object? documentsError;

  @override
  Future<List<DriverDocument>> documents() async {
    final err = documentsError;
    if (err != null) throw err as Exception;
    return documentsResult;
  }

  @override
  Future<void> goOnline() async {}

  @override
  Future<void> goOffline() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
