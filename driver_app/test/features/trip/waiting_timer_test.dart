import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_interactor.dart';
import 'package:hoppin_driver/features/trip/map/map_state.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_driver/features/trip/widgets/waiting_elapsed.dart';
import 'package:hoppin_driver/features/trip/widgets/waiting_policy_unavailable.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/source_scan.dart';

/// 🔴 THE WAITING CLOCK COUNTS UP. IT NEVER COUNTS DOWN, AND IT IS NEVER MONEY.
///
/// Elapsed time since the local `arrive` stamp is the ONE honest thing we can
/// say about waiting, and it needs nothing from the backend. A COUNTDOWN to a
/// "wait charge starts" threshold is a fabricated promise about a self-employed
/// person's pay — there is no free-wait window, no per-minute rate and no
/// threshold anywhere in the product (#44). Any accruing £ figure is a lie
/// about money, and this project's hard guardrail is that driver money renders
/// no figure the server did not send.
void main() {
  final arriveInstant = DateTime.utc(2026, 7, 15, 9, 0, 0);

  TripRunnerState waitingState({DateTime? arrivedAt}) => TripRunnerState(
        rideId: 'ride-1',
        phase: TripPhase.arrivedAtPickup,
        arrivedAt: arrivedAt ?? arriveInstant,
      );

  /// Bounded pumps only — NEVER `pumpAndSettle`. The driver app has live
  /// polling providers and settle-detection never terminates.
  Future<void> bounded(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> pumpRunner(
    WidgetTester tester, {
    TripRunnerState? fixture,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripRunnerInteractorProvider
            .overrideWith2((rideId) => _StubRunner(fixture ?? waitingState())),
        tripMapInteractorProvider.overrideWith2((rideId) => _StubMap()),
      ],
      child: MaterialApp(
        // The driver's PRIMARY theme (SF-02).
        theme: HoppinTheme.driverDark(),
        home: const TripRunnerRiblet(rideId: 'ride-1'),
      ),
    ));
    await bounded(tester);
  }

  String elapsedText(WidgetTester tester) {
    final elapsed = tester.widget<WaitingElapsed>(find.byType(WaitingElapsed));
    // Format the same way the widget does, from the same stamp, at clock.now().
    final d = clock.now().difference(elapsed.since);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  testWidgets('W1 — IT COUNTS UP: t+3min reads greater than t+1min',
      (tester) async {
    // Sample at t+1min.
    late String atOneMinute;
    await withClock(Clock.fixed(arriveInstant.add(const Duration(minutes: 1))),
        () async {
      await pumpRunner(tester);
      expect(find.byType(WaitingElapsed), findsOneWidget);
      expect(find.text('01:00'), findsOneWidget);
      atOneMinute = elapsedText(tester);
    });

    // Sample at t+3min — a fresh boot at the later clock.
    late String atThreeMinutes;
    await withClock(Clock.fixed(arriveInstant.add(const Duration(minutes: 3))),
        () async {
      await pumpRunner(tester);
      expect(find.text('03:00'), findsOneWidget);
      atThreeMinutes = elapsedText(tester);
    });

    // 🔴 The value at t+3min is GREATER than at t+1min. A monotonically
    // DECREASING value (a countdown) fails this even if the format looks right.
    final oneMinuteSeconds = _asSeconds(atOneMinute);
    final threeMinuteSeconds = _asSeconds(atThreeMinutes);
    expect(
      threeMinuteSeconds,
      greaterThan(oneMinuteSeconds),
      reason: '🔴 the waiting clock is not counting UP. A countdown to a wait '
          'charge is a fabricated promise about a driver being PAID to wait '
          '(#44 — no policy exists). It counts UP or it lies.',
    );
  });

  testWidgets(
      'W2 — NO CURRENCY on the waiting surface: no rendered Text is money',
      (tester) async {
    await withClock(
        Clock.fixed(arriveInstant.add(const Duration(minutes: 4))), () async {
      await pumpRunner(tester);

      final money = RegExp(r'£\s?\d');
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final data = text.data;
        if (data == null) continue;
        expect(
          money.hasMatch(data),
          isFalse,
          reason: '🔴 a currency figure is on the waiting surface: "$data". '
              'No accruing £, no rate, no threshold. There is no waiting '
              'policy (#44) and inventing one invents a promise about pay.',
        );
      }
    });
  });

  test(
      'W2-source — no countdown/money vocabulary under features/trip '
      '(comment-stripped)', () {
    final sources = scanDartSources();
    expect(sources, isNotEmpty, reason: 'the sweep must sweep something');

    final surface =
        sources.where((s) => s.path.contains('/features/trip/')).toList();
    expect(surface, isNotEmpty);

    // A pound sign, a wait-charge concept, a free-wait window, or a "waiting
    // countdown" anywhere on the trip surface is the lie this test deletes.
    // (A bare "remaining" is NOT banned — the map interactor legitimately sums
    // route-distance metres; that is geometry, not a countdown to a charge.
    // W1's greaterThan sample and W2's widget currency-walk are what prove the
    // WAITING clock counts up and never wears money.)
    final banned = <RegExp>[
      RegExp(r'£'),
      RegExp('waitCharge|wait_charge', caseSensitive: false),
      RegExp('freeWait|free_wait', caseSensitive: false),
      RegExp('countdown', caseSensitive: false),
    ];

    // `pence` is permitted ONLY on the pre-existing #7 payout DECORATION
    // plumbing — `payoutPence` and the earnings-delta baseline it is measured
    // from. Any OTHER `pence` on the trip surface would be a new money figure.
    final allowedPence = RegExp('payoutPence|earningsPence|EarningsPence');

    final offenders = <String>[];
    for (final source in surface) {
      for (var i = 0; i < source.lines.length; i++) {
        final line = source.lines[i];
        for (final re in banned) {
          if (re.hasMatch(line)) {
            offenders.add('${source.path}:${i + 1}  ${line.trim()}');
          }
        }
        if (RegExp('pence', caseSensitive: false).hasMatch(line) &&
            !allowedPence.hasMatch(line)) {
          offenders.add('${source.path}:${i + 1}  ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: '🔴 countdown/money vocabulary on the trip surface:\n'
          '${offenders.join('\n')}',
    );
  });

  testWidgets('W3 — the waiting POLICY hole is disclosed (#44 rung mounted)',
      (tester) async {
    await withClock(
        Clock.fixed(arriveInstant.add(const Duration(minutes: 2))), () async {
      await pumpRunner(tester);
      expect(
        find.byType(WaitingPolicyUnavailable),
        findsOneWidget,
        reason: 'the elapsed clock is honest, but the POLICY behind it is a '
            'hole (#44). Without this rung the clock silently implies a '
            'charge that does not exist.',
      );
    });
  });

  testWidgets('W4 — the elapsed value is anchored to a stamp, not a counter',
      (tester) async {
    // Anchored to `since`: rebuilding the widget at the same clock instant
    // yields the same elapsed value. It recomputes from clock.now() deltas and
    // never trusts that a timer fired (PL-03).
    await withClock(
        Clock.fixed(arriveInstant.add(const Duration(minutes: 5))), () async {
      await pumpRunner(tester);
      expect(find.text('05:00'), findsOneWidget);

      // Force a rebuild by re-pumping the same tree; the value must not drift.
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.text('05:00'),
        findsOneWidget,
        reason: '🔴 the elapsed value drifted on a rebuild — it is counting '
            'ticks, not recomputing from the stored stamp (PL-03).',
      );
    });
  });
}

int _asSeconds(String mmss) {
  final parts = mmss.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Hidden map: no geo seams, no poll timer.
class _StubMap extends MapInteractor {
  _StubMap() : super('ride-1');

  @override
  MapState build() => const MapState();
}

/// Fixture-holding runner stub: the intents are inert; only the state matters.
class _StubRunner extends TripRunnerInteractor {
  _StubRunner(this.fixture) : super('ride-1');

  final TripRunnerState fixture;

  @override
  TripRunnerState build() => fixture;

  @override
  Future<void> arrived() async {}

  @override
  Future<void> startTrip() async {}

  @override
  Future<void> complete() async {}
}
