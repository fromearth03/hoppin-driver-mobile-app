import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/dashboard/widgets/seam_unavailable_states.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_interactor.dart';
import 'package:hoppin_driver/features/trip/map/map_state.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 DO NOT DRAW A PERSON WHO DOES NOT EXIST.
///
/// `GET /drivers/me/offers` carries coordinates and fare. Nothing else.
/// `tripRiderContext()` (#6) answers null on every live request. The Figma
/// confidently renders "Sarah Johnson ★4.9 (94 trips)". None of it exists. On
/// the live (null) path the trip surface must render NO fabricated name,
/// rating, photo or trip count — and the #6 rung must be MOUNTED where the face
/// would be.
void main() {
  const rideId = 'ride-1';

  /// Bounded pumps only — NEVER `pumpAndSettle`.
  Future<void> bounded(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Boots the runner at [phase] with a chosen rider context. Live path =
  /// null (exactly as `tripRiderContext()` answers on live).
  Future<void> pumpRunner(
    WidgetTester tester, {
    required TripPhase phase,
    TripRiderContext? rider,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripRunnerInteractorProvider
            .overrideWith2((id) => _Runner(phase: phase, rider: rider)),
        tripMapInteractorProvider.overrideWith2((id) => _StubMap()),
      ],
      child: MaterialApp(
        theme: HoppinTheme.driverDark(),
        home: const TripRunnerRiblet(rideId: rideId),
      ),
    ));
    await bounded(tester);
  }

  // ── R1 — NOT ONE FABRICATED CHARACTER, at every phase ───────────────────
  group('🔴 R1 — no fabricated rider identity on the live (null) path', () {
    for (final phase in TripPhase.values) {
      testWidgets('$phase renders no name, rating, star or trip count',
          (tester) async {
        await pumpRunner(tester, phase: phase, rider: null);

        final rating = RegExp(r'\d\.\d');
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          final data = text.data;
          if (data == null) continue;
          expect(rating.hasMatch(data), isFalse,
              reason: '🔴 a rating shape "$data" rendered over a null seam');
          expect(data.contains('★'), isFalse,
              reason: '🔴 a star rating rendered over a null seam: "$data"');
          expect(data.toLowerCase().contains('trips'), isFalse,
              reason: '🔴 a trip count rendered over a null seam: "$data"');
          expect(data.contains('Sarah'), isFalse,
              reason: '🔴 the fabricated persona "Sarah" appeared: "$data"');
        }
      });
    }
  });

  // ── R2 — the #6 rung is MOUNTED on the trip surface ─────────────────────
  testWidgets('R2 — RiderContextUnavailable is mounted where the face would be',
      (tester) async {
    await pumpRunner(tester, phase: TripPhase.headingToPickup, rider: null);
    expect(
      find.byType(RiderContextUnavailable),
      findsOneWidget,
      reason: 'Group C requires the #6 rung CONSTRUCTED in a real view. The '
          'trip runner is the driver-facing mount site for it.',
    );
  });

  // ── R3 — what we DO have, we show ───────────────────────────────────────
  //
  // RECONCILED WITH THE DATA CONTRACT: neither `Ride` nor `RideOffer` carries
  // pickup/dropoff ADDRESS TEXT — the offer payload is coordinates + fare only
  // (confirmed against the models). The ONLY address text on this surface is
  // `TripRiderContext.pickupLabel`, which is the seam: null on live. So "the
  // address we genuinely have" is the pickupLabel that arrives WHEN the seam
  // answers (the demo/populated path). On the live/null path there is no
  // address to show — and we invent none. Honesty is not austerity: when we
  // have the label, we render it; when we do not, we say so (R2) and fabricate
  // nothing (R1).
  testWidgets('R3 — the pickup label renders when the seam provides it',
      (tester) async {
    const rider = (
      name: 'Sophie Bell',
      rating: 4.8,
      pickupLabel: 'Wolverhampton Rail Station',
      pickupEtaSeconds: 120,
    );
    await pumpRunner(
      tester,
      phase: TripPhase.headingToPickup,
      rider: rider,
    );
    expect(find.text('Wolverhampton Rail Station'), findsOneWidget,
        reason: 'strip the invented person, keep the real address');
  });
}

class _StubMap extends MapInteractor {
  _StubMap() : super('ride-1');

  @override
  MapState build() => const MapState();
}

class _Runner extends TripRunnerInteractor {
  _Runner({required this.phase, required this.rider}) : super('ride-1');

  final TripPhase phase;
  final TripRiderContext? rider;

  @override
  TripRunnerState build() => TripRunnerState(
        rideId: 'ride-1',
        phase: phase,
        riderContext: rider,
        etaSeconds: phase == TripPhase.headingToPickup ? 90 : null,
        arrivedAt: phase.index >= TripPhase.arrivedAtPickup.index
            ? DateTime.utc(2026, 7, 15, 9)
            : null,
      );

  @override
  Future<void> arrived() async {}

  @override
  Future<void> startTrip() async {}

  @override
  Future<void> complete() async {}
}
