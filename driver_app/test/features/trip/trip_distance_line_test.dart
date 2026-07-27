import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_interactor.dart';
import 'package:hoppin_driver/features/trip/map/map_state.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 DISTANCE ON THE CARD IS GEOMETRY OR IT IS NOTHING.
///
/// The Figma draws a Distance/ETA trio at the top of the trip card. The ONE
/// honest distance the app has is `MapState.remainingMeters` — summed along the
/// current leg from the car's own position by the map interactor, and already
/// gated there on `legEndsAtObjective` so a leg that does not END at the
/// objective yields null rather than a plausible-looking number.
///
/// This suite pins the consequence: the card renders that figure when the
/// geometry genuinely exists, and renders NOTHING when it does not. On live
/// BOTH geo seams (#41 driverPosition, #17 rideGeo) answer null on every
/// request — MapPhase.hidden — so the null branch is the ONLY branch live ever
/// reaches. A distance invented to fill that gap would be a lie about how far a
/// driver is from a rider.
///
/// Fare is deliberately absent: `TripRunnerState` carries no fare, the runner
/// is keyed only by rideId, and the `Ride` it receives carries `fare_id` — an
/// opaque string with no resolver anywhere in the codebase. Rendering money
/// here would fabricate it.
void main() {
  const heading = TripRunnerState(rideId: 'ride-1', etaSeconds: 90);

  Future<void> pumpRunner(
    WidgetTester tester, {
    required MapState map,
    TripRunnerState? runner,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripRunnerInteractorProvider
            .overrideWith2((rideId) => _StubRunner(runner ?? heading)),
        tripMapInteractorProvider.overrideWith2((rideId) => _StubMap(map)),
      ],
      child: MaterialApp(
        theme: theme ?? HoppinTheme.driverDark(),
        home: const TripRunnerRiblet(rideId: 'ride-1'),
      ),
    ));
    // Bounded pumps only — the driver app has live polling providers and
    // settle-detection never terminates.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// A tracking map with real geometry: 2.4 km left along the leg.
  const tracking = MapState(
    phase: MapPhase.liveTracking,
    carPosition: HopGeoPoint(52.5865, -2.1288),
    remainingMeters: 2414,
  );

  testWidgets(
      'D1 — a REAL along-leg distance renders on the card beside the ETA',
      (tester) async {
    await pumpRunner(tester, map: tracking);

    // 1.5 mi — 2414 m converted at the same 1609.344 m/mi the map chip uses.
    expect(
      find.text('1.5 mi to pickup'),
      findsOneWidget,
      reason: '🔴 the card drew no distance while the map interactor HAD an '
          'honest along-leg figure (2414 m). This is real geometry — summed '
          'from the car position the location seam supplied — and the Figma '
          'draws it. Rendering only the ETA throws it away.',
    );
    // 🔴 The ETA stays EXACTLY findable beside the distance. The two are
    // separate Text widgets, not a joined string — a join makes the ETA
    // unfindable the moment geometry appears next to it.
    expect(find.text('1:30 to pickup'), findsOneWidget);
  });

  testWidgets(
      'D2 — 🔴 THE LIVE RUNG: a hidden map (both geo seams null) renders NO '
      'distance, never a fabricated one', (tester) async {
    // MapPhase.hidden with remainingMeters null IS live: #41 and #17 both
    // answer null on every request, so this is the only branch live reaches.
    await pumpRunner(tester, map: const MapState());

    // Nothing that reads as a distance may appear. Sweep every rendered Text.
    final distance = RegExp(r'\d+(\.\d+)?\s*(mi|miles|km|m)\b');
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;
      expect(
        distance.hasMatch(data),
        isFalse,
        reason: '🔴 a distance figure rendered with NO geometry behind it: '
            '"$data". Both geo seams answer null on live (#41/#17) — any '
            'number here is invented, and a driver would believe it.',
      );
    }
    // The honest ETA line is unaffected by the missing geometry.
    expect(find.text('1:30 to pickup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'D3 — geometry without an along-leg figure stays silent '
      '(routeOnly, remainingMeters null)', (tester) async {
    // The degraded middle rung: #17 ships before #41 — route geometry exists,
    // but with no car position there is no honest distance FROM anywhere.
    await pumpRunner(
      tester,
      map: const MapState(phase: MapPhase.routeOnly),
    );

    final distance = RegExp(r'\d+(\.\d+)?\s*(mi|miles|km|m)\b');
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = text.data;
      if (data == null) continue;
      expect(
        distance.hasMatch(data),
        isFalse,
        reason: '🔴 a distance rendered on the routeOnly rung: "$data". With '
            'no car position there is no distance from the driver to '
            'anything — the map interactor correctly answered null and the '
            'card must respect that.',
      );
    }
  });

  testWidgets('D4 — the distance follows the OBJECTIVE, not a fixed word',
      (tester) async {
    // The objective is the map's to declare — it flips to the drop-off with
    // the pin and the track in one emission. The card must READ that word,
    // never assume 'pickup'.
    await pumpRunner(
      tester,
      map: const MapState(
        phase: MapPhase.liveTracking,
        carPosition: HopGeoPoint(52.5865, -2.1288),
        remainingMeters: 8047, // 5.0 mi
        objectiveLabel: 'Drop-off',
      ),
    );

    expect(
      find.text('5.0 mi to drop-off'),
      findsOneWidget,
      reason: '🔴 the card said "pickup" while the objective was the '
          'drop-off. The label flips WITH the pin and the track — the card '
          'must read the objective, not assume one.',
    );
  });

  testWidgets(
      'D6 — an ETA with NO geometry still renders alone (the live rung keeps '
      'the honest half)', (tester) async {
    await pumpRunner(tester, map: const MapState());

    // The ETA is telemetry, not geometry — it survives both geo seams being
    // null, and it must not be dragged down by the missing distance.
    expect(find.text('1:30 to pickup'), findsOneWidget);
  });

  testWidgets('D5 — both themes pump clean with the distance mounted',
      (tester) async {
    for (final theme in [HoppinTheme.driverDark(), HoppinTheme.driverLight()]) {
      await pumpRunner(tester, map: tracking, theme: theme);
      expect(find.text('1.5 mi to pickup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

/// Fixture-holding map stub: no seams, no poll timer — the state IS the
/// fixture.
class _StubMap extends MapInteractor {
  _StubMap(this.fixture) : super('ride-1');

  final MapState fixture;

  @override
  MapState build() => fixture;
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
