import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_interactor.dart';
import 'package:hoppin_driver/features/trip/map/map_state.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_driver/features/trip/trip_runner_view.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// View smoke layer (riblet testing contract, DOCS/05): state in → widgets
/// out against fixed fixtures, intents dispatched exactly once, and the
/// ONE structural guarantee of DRIVER-03 — the bottom card is a single
/// persistent element that MORPHS across phases, never remounting.
/// Bounded pumps only.
void main() {
  const TripRiderContext sophie = (
    name: 'Sophie Bell',
    rating: 4.8,
    pickupLabel: 'Wolverhampton Rail Station',
    pickupEtaSeconds: 120,
  );

  const heading = TripRunnerState(
    rideId: 'ride-1',
    etaSeconds: 90,
    riderContext: sophie,
  );
  const arrived = TripRunnerState(
    rideId: 'ride-1',
    phase: TripPhase.arrivedAtPickup,
    riderContext: sophie,
  );
  const inTrip = TripRunnerState(
    rideId: 'ride-1',
    phase: TripPhase.inTrip,
    riderContext: sophie,
  );

  const cardKey = ValueKey('trip-runner-card');

  Future<_StubInteractor> pumpRunner(
    WidgetTester tester,
    TripRunnerState fixture, {
    ThemeData? theme,
  }) async {
    final stub = _StubInteractor(fixture);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripRunnerInteractorProvider.overrideWith2((rideId) => stub),
        // Hermetic map: the embedded MAP-04 canvas stays hidden here (its
        // own suite exercises it) — no geo seams, no poll timer.
        tripMapInteractorProvider.overrideWith2((rideId) => _StubMap()),
      ],
      child: MaterialApp(
        theme: theme ?? HoppinTheme.driverDark(),
        home: const TripRunnerRiblet(rideId: 'ride-1'),
      ),
    ));
    await tester.pump();
    return stub;
  }

  Future<void> settleMorph(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('headingToPickup: destination headline, ETA, rider row, tap',
      (tester) async {
    await pumpRunner(tester, heading);

    expect(find.text('Head to Wolverhampton Rail Station'), findsOneWidget);
    expect(find.text('1:30 to pickup'), findsOneWidget);
    expect(find.text('Sophie Bell'), findsOneWidget);
    expect(find.text('★ 4.8'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('On board'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    final spine =
        tester.widget<TripStageSpine>(find.byType(TripStageSpine));
    expect(spine.activeIndex, 0);
    expect(find.text('Arrived'), findsOneWidget);
    expect(find.byType(SlideToConfirm), findsNothing);
  });

  testWidgets('eta 0 renders the calm Arriving now', (tester) async {
    await pumpRunner(tester, heading.copyWith(etaSeconds: 0));

    expect(find.text('Arriving now'), findsOneWidget);
    expect(find.text('Arrived'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card morphs across phases without remounting',
      (tester) async {
    final stub = await pumpRunner(tester, heading);
    final before = tester.element(find.byKey(cardKey));

    stub.emit(arrived);
    await settleMorph(tester);

    expect(find.text('Waiting for Sophie'), findsOneWidget);
    final slide =
        tester.widget<SlideToConfirm>(find.byType(SlideToConfirm));
    expect(slide.label, 'Slide to start trip');
    expect(find.text('Arrived'), findsNothing);

    // The state morph, not a remount: the SAME element renders the card.
    final after = tester.element(find.byKey(cardKey));
    expect(identical(before, after), isTrue,
        reason: 'the persistent card must never unmount between phases');
  });

  testWidgets('inTrip: progress headline, complete slide, second dot active',
      (tester) async {
    await pumpRunner(tester, inTrip);

    expect(find.text('Trip in progress'), findsOneWidget);
    final slide =
        tester.widget<SlideToConfirm>(find.byType(SlideToConfirm));
    expect(slide.label, 'Slide to complete');
    final spine =
        tester.widget<TripStageSpine>(find.byType(TripStageSpine));
    expect(spine.activeIndex, 1);
  });

  testWidgets('null rider context falls back gracefully (live degrade)',
      (tester) async {
    final stub = await pumpRunner(
      tester,
      const TripRunnerState(rideId: 'ride-1', etaSeconds: 90),
    );

    expect(find.text('Head to pickup'), findsOneWidget);
    expect(tester.takeException(), isNull);

    stub.emit(
      const TripRunnerState(
        rideId: 'ride-1',
        phase: TripPhase.arrivedAtPickup,
      ),
    );
    await settleMorph(tester);

    expect(find.text('Waiting for your rider'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error surfaces as the brand HopBanner, never a red screen',
      (tester) async {
    const message = 'Something went wrong. Please try again.';
    await pumpRunner(tester, heading.copyWith(error: message));

    expect(find.text(message), findsOneWidget);
    expect(find.byType(HopBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap Arrived dispatches arrived() exactly once', (tester) async {
    final stub = await pumpRunner(tester, heading);

    await tester.tap(find.text('Arrived'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(stub.arrivedCalls, 1);
    expect(stub.startTripCalls, 0);
    expect(stub.completeCalls, 0);
  });

  testWidgets('slide past threshold dispatches startTrip() exactly once',
      (tester) async {
    final stub = await pumpRunner(tester, arrived);

    await tester.drag(
      find.byIcon(Icons.chevron_right),
      const Offset(600, 0),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(stub.startTripCalls, 1);
    expect(stub.arrivedCalls, 0);
    expect(stub.completeCalls, 0);
  });
}

/// Hidden-map stub: build() returns the default (hidden) state and never
/// arms the 1 Hz seam poll — the runner renders its canvas-less layout.
class _StubMap extends MapInteractor {
  _StubMap() : super('ride-1');

  @override
  MapState build() => const MapState();
}

/// Fixture-holding stub: build() returns the fixed state, [emit] swaps it
/// live (the morph trigger), and the intent methods record instead of
/// acting.
class _StubInteractor extends TripRunnerInteractor {
  _StubInteractor(this.fixture) : super('ride-1');

  final TripRunnerState fixture;
  int arrivedCalls = 0;
  int startTripCalls = 0;
  int completeCalls = 0;

  @override
  TripRunnerState build() => fixture;

  void emit(TripRunnerState next) => state = next;

  @override
  Future<void> arrived() async {
    arrivedCalls++;
  }

  @override
  Future<void> startTrip() async {
    startTripCalls++;
  }

  @override
  Future<void> complete() async {
    completeCalls++;
  }
}
