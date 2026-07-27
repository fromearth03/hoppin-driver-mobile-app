// Acceptance tests for HopMap — the single pure-presentation seam around
// maplibre_gl (06-02). The contracts under test:
//
// - RETARGET: the car marker tweens linearly from the CURRENTLY SHOWN
//   position to each new sample over the sample interval — never a frame at
//   the new sample before the tween completes (the never-teleport contract).
// - RETARGET-FROM-SHOWN: a mid-tween sample starts the new tween from the
//   intermediate shown position, not from the old begin or the new end.
// - SNAP RULE: a jump >150 m from the shown position, or a host-supplied
//   sample gap >3x the sample interval, renders AT the new position on the
//   very next frame (deliberate snap — throttled-tab/F5 protection), then
//   subsequent samples tween again.
// - NON-INTERACTIVE: interactive:false wraps in an IgnorePointer.
// - ATTRIBUTION: OSM attribution is present in BOTH themes (policy).
// - NULL LADDER: null carPosition -> no car marker; null track -> no
//   route annotation (pins-only render).
//
// Bounded pumps ONLY — the marker tween never settles.
// The maplibre_gl platform view is suppressed by passing a non-null
// tileProvider sentinel so tests stay headless and network-free. The car
// marker is a Flutter widget (HopMapCarMarker) and fully introspectable.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

final Map<String, ThemeData> themes = <String, ThemeData>{
  'riderLight': HoppinTheme.riderLight(),
  'riderDark': HoppinTheme.riderDark(),
};

// Wolverhampton-ish sample ladder, ~89 m apart going north (well under the
// 150 m snap threshold), plus a deliberate long jump for the snap rule.
const a = HopGeoPoint(52.5877, -2.1200);
const b = HopGeoPoint(52.5885, -2.1200);
const c = HopGeoPoint(52.5893, -2.1200);
const far = HopGeoPoint(52.5920, -2.1200); // ~478 m from [a]
const farNext = HopGeoPoint(52.5928, -2.1200); // ~89 m past [far]

/// Sentinel: a non-null tileProvider suppresses the MapLibreMap platform view
/// so tests never issue tile HTTP or require a native renderer.
const Object _noNetwork = 'no-network';

Future<void> pumpMap(
  WidgetTester tester, {
  List<HopMapPin> pins = const [],
  HopMapTrack? track,
  HopGeoPoint? carPosition,
  double? carHeading,
  Duration? sampleGap,
  HopMapCameraIntent cameraIntent = const FollowPoint(a),
  bool follow = true,
  bool interactive = true,
  VoidCallback? onUserGesture,
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme ?? themes['riderLight'],
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 480,
            child: HopMap(
              pins: pins,
              track: track,
              carPosition: carPosition,
              carHeading: carHeading,
              sampleGap: sampleGap,
              cameraIntent: cameraIntent,
              follow: follow,
              interactive: interactive,
              onUserGesture: onUserGesture ?? () {},
              tileProvider: _noNetwork,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Reads the car marker's currently shown lat/lng from the Flutter overlay.
/// Fails if no [HopMapCarMarker] is found — call only when carPosition is set.
({double lat, double lng}) shownCarPoint(WidgetTester tester) {
  final marker = tester.widget<HopMapCarMarker>(
    find.byKey(HopMap.carMarkerKey),
  );
  return (lat: marker.lat, lng: marker.lng);
}

void main() {
  group('HopMap never-teleport marker', () {
    testWidgets('tweens linearly from A to B — strictly between mid-interval,'
        ' at B only after the full interval', (tester) async {
      await pumpMap(tester, carPosition: a);
      await tester.pump();
      expect(shownCarPoint(tester).lat, closeTo(a.lat, 1e-9));

      await pumpMap(tester, carPosition: b);
      // The retarget frame itself must still show A (t=0).
      expect(shownCarPoint(tester).lat, closeTo(a.lat, 1e-9));

      // Mid-interval: strictly between, at the linear midpoint.
      await tester.pump(const Duration(milliseconds: 500));
      final mid = shownCarPoint(tester);
      expect(mid.lat, greaterThan(a.lat));
      expect(mid.lat, lessThan(b.lat));
      expect(mid.lat, closeTo((a.lat + b.lat) / 2, 1e-4));

      // Never a frame at B before the tween completes.
      await tester.pump(const Duration(milliseconds: 400));
      expect(shownCarPoint(tester).lat, lessThan(b.lat));

      // The full interval has elapsed — the marker has arrived.
      await tester.pump(const Duration(milliseconds: 200));
      expect(shownCarPoint(tester).lat, closeTo(b.lat, 1e-9));
      expect(shownCarPoint(tester).lng, closeTo(b.lng, 1e-9));
    });

    testWidgets('mid-tween retarget starts from the SHOWN position — no jump'
        ' back to A, no snap to C', (tester) async {
      await pumpMap(tester, carPosition: a);
      await tester.pump();
      await pumpMap(tester, carPosition: b);
      await tester.pump(const Duration(milliseconds: 500));
      final shownMid = shownCarPoint(tester).lat;
      expect(shownMid, closeTo((a.lat + b.lat) / 2, 1e-4));

      // Retarget to C mid-tween: the new tween's origin is the shown point.
      await pumpMap(tester, carPosition: c);
      expect(shownCarPoint(tester).lat, closeTo(shownMid, 1e-6));
      await tester.pump(const Duration(milliseconds: 16));
      final justAfter = shownCarPoint(tester).lat;
      expect(justAfter, greaterThanOrEqualTo(shownMid - 1e-6));
      expect(justAfter, lessThan(shownMid + (c.lat - shownMid) * 0.1));

      // And it keeps tweening towards C from there.
      await tester.pump(const Duration(milliseconds: 500));
      final later = shownCarPoint(tester).lat;
      expect(later, greaterThan(justAfter));
      expect(later, lessThan(c.lat));
    });
  });

  group('HopMap snap rule', () {
    testWidgets('a jump >150m renders AT the new position immediately, then'
        ' subsequent samples tween again', (tester) async {
      await pumpMap(tester, carPosition: a);
      await tester.pump();

      // ~478m jump — deliberate snap, no glide across town.
      await pumpMap(tester, carPosition: far);
      await tester.pump(const Duration(milliseconds: 16));
      expect(shownCarPoint(tester).lat, closeTo(far.lat, 1e-9));

      // The next small sample tweens normally from the snapped position.
      await pumpMap(tester, carPosition: farNext);
      await tester.pump(const Duration(milliseconds: 500));
      final mid = shownCarPoint(tester);
      expect(mid.lat, greaterThan(far.lat));
      expect(mid.lat, lessThan(farNext.lat));
    });

    testWidgets('a host-supplied sample gap >3x the interval snaps even for'
        ' a small jump', (tester) async {
      await pumpMap(tester, carPosition: a);
      await tester.pump();

      await pumpMap(
        tester,
        carPosition: b,
        sampleGap: const Duration(seconds: 5),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(shownCarPoint(tester).lat, closeTo(b.lat, 1e-9));
    });
  });

  group('HopMap non-interactive inset (MAP-04)', () {
    testWidgets('interactive:false wraps in IgnorePointer', (tester) async {
      await pumpMap(tester, carPosition: a, interactive: false);
      await tester.pump();

      // The IgnorePointer is a descendant of HopMap (wraps the inner stack).
      final ignore = tester.widget<IgnorePointer>(
        find
            .descendant(
              of: find.byType(HopMap),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignore.ignoring, isTrue);
    });
  });

  group('HopMap attribution (OSM policy)', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('attribution is visible ($name)', (tester) async {
        await pumpMap(tester, carPosition: a, theme: theme);
        await tester.pump();
        expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      });
    }
  });

  group('HopMap null ladder', () {
    testWidgets('null carPosition renders no car marker', (tester) async {
      await pumpMap(
        tester,
        pins: const [HopMapPin(a, HopMapPinRole.pickup)],
      );
      await tester.pump();
      expect(find.byKey(HopMap.carMarkerKey), findsNothing);
    });

    testWidgets('non-null carPosition renders the car marker', (tester) async {
      await pumpMap(tester, carPosition: a);
      await tester.pump();
      expect(find.byKey(HopMap.carMarkerKey), findsOneWidget);
    });
  });

  group('HopMap hygiene', () {
    testWidgets('sits under a RepaintBoundary and never mounts an Opacity', (
      tester,
    ) async {
      await pumpMap(
        tester,
        carPosition: a,
        track: const HopMapTrack([a, b, c]),
        pins: const [HopMapPin(a, HopMapPinRole.pickup)],
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(
          of: find.byType(HopMap),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(HopMap),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });
  });
}
