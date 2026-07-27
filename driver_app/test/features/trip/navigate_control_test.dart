import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_interactor.dart';
import 'package:hoppin_driver/features/trip/map/map_state.dart';
import 'package:hoppin_driver/features/trip/trip_nav_handoff.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 OT-16 — the driver can HAND OFF to external turn-by-turn nav.
///
/// `launchNavHandoff` / `buildNavHandoffUrl` were built and bound to the
/// gateway, and NO production control ever called `launchNavHandoff`: a driver
/// at the wheel had no "Navigate" button, and OT-16 was counted delivered while
/// being unreachable in the UI. This test drives the REAL runner surface, taps
/// the Navigate control, and asserts exactly one launch of the expected Maps
/// URL for the current leg's destination. It FAILS on today's code (no control).
///
/// 🔴 THE CONTROL STAYS LIVE IN MOTION — a driver navigating is exactly the
/// in-motion case, and it is a single tap, not text entry. It is NOT wrapped in
/// the typing lock (that is 15-00's gate side B).
///
/// Bounded pumps only.
void main() {
  const objective = HopGeoPoint(52.6046, -2.1103);

  Future<_RecordingLauncher> pumpRunner(
    WidgetTester tester,
    TripPhase phase,
  ) async {
    final launcher = _RecordingLauncher();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripRunnerInteractorProvider
            .overrideWith2((rideId) => _StubInteractor(phase)),
        tripMapInteractorProvider
            .overrideWith2((rideId) => _StubMap(objective)),
        urlLauncherProvider.overrideWithValue(launcher),
      ],
      child: MaterialApp(
        theme: HoppinTheme.driverDark(),
        home: const TripRunnerRiblet(rideId: 'ride-1'),
      ),
    ));
    await tester.pump();
    return launcher;
  }

  testWidgets('a Navigate control exists on the trip surface and hands off',
      (tester) async {
    final launcher = await pumpRunner(tester, TripPhase.headingToPickup);

    final navigate = find.widgetWithText(HopButton, 'Navigate');
    expect(navigate, findsOneWidget,
        reason: '🔴 the driver needs a one-tap hand-off to Google Maps');

    await tester.tap(navigate);
    await tester.pump(const Duration(milliseconds: 100));

    expect(launcher.launched, hasLength(1),
        reason: 'exactly one launch through the gateway');
    final uri = launcher.launched.single;
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['destination'], '52.6046,-2.1103',
        reason: 'the hand-off targets the current leg destination');
  });

  testWidgets('after the trip starts, the hand-off targets the drop-off',
      (tester) async {
    // The map interactor flips the objective from pickup to drop-off on start;
    // the control launches whatever destination the map reports.
    final launcher = await pumpRunner(tester, TripPhase.inTrip);

    await tester.tap(find.widgetWithText(HopButton, 'Navigate'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(launcher.launched.single.queryParameters['destination'],
        '52.6046,-2.1103');
  });
}

/// A map stub that reports a fixed objective destination — pin + destination
/// flip together in the real interactor; here it is a constant.
class _StubMap extends MapInteractor {
  _StubMap(this._objective) : super('ride-1');

  final HopGeoPoint _objective;

  @override
  MapState build() => MapState(destination: _objective);
}

class _StubInteractor extends TripRunnerInteractor {
  _StubInteractor(this.phase) : super('ride-1');

  final TripPhase phase;

  @override
  TripRunnerState build() =>
      TripRunnerState(rideId: 'ride-1', phase: phase);
}

class _RecordingLauncher implements UrlLauncher {
  final launched = <Uri>[];

  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    return false;
  }
}
