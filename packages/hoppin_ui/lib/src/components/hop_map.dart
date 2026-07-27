/// HopMap — the ONE place in the codebase that touches maplibre_gl.
///
/// Pure presentation (riblet rule): pins/track/position/camera-intent in,
/// gestures out. Feature code speaks only the pure-Dart vocabulary in
/// hop_map_models.dart, so swapping the tile provider or the whole map engine
/// later is a change inside this file only.
///
/// The smoothness contract (06-CONTEXT):
/// - The car marker NEVER teleports: each new sample retargets a linear
///   lat/lng tween from the currently shown position over the sample
///   interval. Chained linear segments read as continuous motion — eased
///   per-sample curves would pulse stop-start.
/// - Deliberate snap: a jump beyond [_snapDistanceMeters] or a host-supplied
///   sample gap over 3x the interval renders at the new position instantly
///   (throttled-tab / F5 protection), then tweening resumes.
/// - The camera obeys declarative intents, debounced, and never fights the
///   user: a gesture fires [HopMap.onUserGesture] and no camera move runs
///   while the host has paused follow.
/// - The car marker is a Flutter-side overlay widget driven by the tween;
///   only tile, route, and pin layers go through MapLibre annotations. The
///   Flutter widget tree remains introspectable by tests.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../theme/context_extension.dart';
import '../theme/hoppin_colors.dart';
import '../theme/hoppin_motion.dart';
import 'hop_map_models.dart';

/// OSM raster style — identical tile source to the admin panel's LiveMap.jsx.
/// Inline JSON so there is no external style URL dependency; works offline
/// (the tile requests themselves still need network, but the style lookup is
/// localhost). Dark-mode swaps are applied by replacing this source with an
/// inverted CSS-filter analogue (a separate dark style string built in
/// [_buildStyleString]).
String _buildStyleString(bool dark) {
  final layers = dark
      ? [
          {
            'id': 'osm-tiles',
            'type': 'raster',
            'source': 'osm',
            'paint': {
              'raster-brightness-min': 0.0,
              'raster-brightness-max': 0.4,
              'raster-saturation': -0.5,
              'raster-hue-rotate': 180.0,
            },
          },
        ]
      : [
          {'id': 'osm-tiles', 'type': 'raster', 'source': 'osm'},
        ];

  return jsonEncode({
    'version': 8,
    'sources': {
      'osm': {
        'type': 'raster',
        'tiles': [
          'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
          'https://b.tile.openstreetmap.org/{z}/{x}/{y}.png',
          'https://c.tile.openstreetmap.org/{z}/{x}/{y}.png',
        ],
        'tileSize': 256,
        'attribution': '© OpenStreetMap contributors',
        'maxzoom': 19,
      },
    },
    'layers': layers,
  });
}

/// The Hoppin map surface: OSM raster tiles (dark tile style in dark theme,
/// attribution always visible), an optional route polyline, styled role pins,
/// a tweened never-teleporting car marker, and an intent-driven eased camera.
/// `interactive: false` renders a fully inert inset — the MAP-04 offer-context
/// mode.
class HopMap extends StatefulWidget {
  const HopMap({
    required this.pins,
    required this.track,
    required this.carPosition,
    required this.carHeading,
    required this.cameraIntent,
    required this.follow,
    required this.interactive,
    required this.onUserGesture,
    this.onCameraIdle,
    this.sampleGap,
    this.sampleInterval = HoppinMotion.mapSampleInterval,
    this.userAgentPackageName = 'com.hoppin.app',
    this.tileProvider,
    super.key,
  });

  /// Styled pins — pickup / destination / objective (role drives the glyph
  /// and tone from theme tokens).
  final List<HopMapPin> pins;

  /// Route polyline; null renders pins only.
  final HopMapTrack? track;

  /// Latest position sample (1 Hz demo tick / live poll); null hides the
  /// car marker entirely.
  final HopGeoPoint? carPosition;

  /// Heading in degrees clockwise from north. Null falls back to the
  /// bearing of the marker's own movement between samples.
  final double? carHeading;

  /// What the camera should frame. HopMap owns HOW (easing, debounce,
  /// gesture pause) — hosts only say what.
  final HopMapCameraIntent cameraIntent;

  /// Host-owned follow switch. While false, intents are recorded but never
  /// applied; flipping back to true re-applies the current intent (the
  /// recenter path).
  final bool follow;

  /// False renders the inert offer-context inset: all gestures disabled plus
  /// an IgnorePointer, and no camera animation beyond the initial framing.
  final bool interactive;

  /// Fired when the user pans/zooms the map — the host flips [follow] off
  /// and shows its recenter affordance.
  final VoidCallback onUserGesture;

  /// Picker mode: fired with the map's centre coordinate after the camera
  /// settles from a user gesture. When non-null the map tracks its camera and
  /// a host can overlay a fixed centre pin and reverse-geocode the settled
  /// point. Null (the default) keeps the map a pure trip-tracking display.
  final void Function(HopGeoPoint centre)? onCameraIdle;

  /// Host-measured time since the previous sample. A gap over 3x
  /// [sampleInterval] triggers the deliberate snap (stale-tab protection).
  final Duration? sampleGap;

  /// Cadence the position samples arrive at — the marker tween runs exactly
  /// this long so the car arrives as the next sample lands. Data cadence,
  /// not motion; the default is 1 Hz ([HoppinMotion.mapSampleInterval]).
  final Duration sampleInterval;

  /// Sent with tile requests on native targets (browsers send their own UA).
  /// Kept for API stability; MapLibre passes the UA from its own config.
  final String userAgentPackageName;

  /// Test seam: when non-null, the map is not mounted (the widget renders a
  /// blank container) and tile HTTP is never issued. Injected by tests that
  /// do not need a rendered map — only the overlay (car marker, attribution).
  ///
  /// The type is [Object?] so apps/rider can stay import-free of maplibre_gl.
  /// Pass any non-null value (e.g. `true`) to suppress the map.
  final Object? tileProvider;

  /// Identifies the car marker's overlay widget — lets tests (and only tests)
  /// find the animated marker among the overlay layers.
  static const Key carMarkerKey = ValueKey<String>('HopMap.carMarker');

  @override
  State<HopMap> createState() => _HopMapState();
}

// ---------------------------------------------------------------------------
// Tween helpers (pure Dart — no map package dependency)
// ---------------------------------------------------------------------------

/// Linear lat/lng interpolation — exact enough at city scale (~3 km route).
class _LatLngPair {
  const _LatLngPair(this.lat, this.lng);
  final double lat;
  final double lng;
  _LatLngPair lerp(_LatLngPair other, double t) => _LatLngPair(
        lat + (other.lat - lat) * t,
        lng + (other.lng - lng) * t,
      );
}

class _LatLngTween extends Tween<_LatLngPair> {
  _LatLngTween({required _LatLngPair super.begin, required _LatLngPair super.end});

  @override
  _LatLngPair lerp(double t) => begin!.lerp(end!, t);
}

// ---------------------------------------------------------------------------

class _HopMapState extends State<HopMap> with TickerProviderStateMixin {
  static const double _snapDistanceMeters = 150;
  static const double _reAimDistanceMeters = 30;
  static const int _staleGapMultiple = 3;
  static const double _fitPaddingPx = 48;
  static const double _pointZoom = 15.5;
  static const double _carSize = 30;

  late final AnimationController _marker = AnimationController(vsync: this);

  _LatLngTween? _carTween;
  Tween<double>? _headingTween;

  // Camera intent debounce state
  _LatLngPair? _lastAimed;
  DateTime? _lastAimedAt;
  bool _mapReady = false;

  MapLibreMapController? _controller;
  String? _styleString;

  // Live annotation IDs, set after style is loaded
  Line? _routeLine;
  final List<Circle> _pinCircles = [];

  @override
  void initState() {
    super.initState();
    final start = widget.carPosition;
    if (start != null) {
      final at = _pair(start);
      _carTween = _LatLngTween(begin: at, end: at);
      final heading = widget.carHeading ?? 0;
      _headingTween = Tween<double>(begin: heading, end: heading);
      _marker.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final newStyle = _buildStyleString(dark);
    if (_styleString != newStyle) {
      _styleString = newStyle;
      // If the controller is already live, update the style (triggers
      // onStyleLoadedCallback which re-adds annotations).
      _controller?.setStyle(newStyle);
    }
  }

  @override
  void didUpdateWidget(HopMap old) {
    super.didUpdateWidget(old);
    if (widget.carPosition != old.carPosition) {
      _onNewSample(widget.carPosition);
    }
    if (widget.track != old.track) {
      _rebuildRoute();
    }
    if (!listEquals(widget.pins, old.pins)) {
      _rebuildPins();
    }
    final resumedFollow = widget.follow && !old.follow;
    if (resumedFollow) {
      _applyIntent(force: true);
    } else if (widget.cameraIntent != old.cameraIntent) {
      _applyIntent();
    }
  }

  @override
  void dispose() {
    _marker.dispose();
    super.dispose();
  }

  // --- Marker tween -------------------------------------------------------

  void _onNewSample(HopGeoPoint? next) {
    if (next == null) {
      _carTween = null;
      _headingTween = null;
      _marker.stop();
      if (mounted) setState(() {});
      return;
    }
    final target = _pair(next);
    final tween = _carTween;
    final shown = tween?.evaluate(_marker);
    if (shown == null) {
      _snapTo(target);
      return;
    }
    final gap = widget.sampleGap;
    final stale =
        gap != null && gap > widget.sampleInterval * _staleGapMultiple;
    final jumpMeters = _haversineMeters(shown.lat, shown.lng, target.lat, target.lng);
    if (stale || jumpMeters > _snapDistanceMeters) {
      _snapTo(target);
      return;
    }
    final shownHeading = _headingTween?.evaluate(_marker) ?? 0;
    final nextHeading =
        widget.carHeading ??
        (jumpMeters > 1
            ? _bearingDeg(shown.lat, shown.lng, target.lat, target.lng)
            : shownHeading);
    _carTween = _LatLngTween(begin: shown, end: target);
    _headingTween = Tween<double>(
      begin: shownHeading,
      end: shownHeading + _shortestArcDelta(shownHeading, nextHeading),
    );
    _marker
      ..duration = widget.sampleInterval
      ..forward(from: 0);
  }

  void _snapTo(_LatLngPair target) {
    final heading =
        widget.carHeading ?? _headingTween?.evaluate(_marker) ?? 0;
    _carTween = _LatLngTween(begin: target, end: target);
    _headingTween = Tween<double>(begin: heading, end: heading);
    _marker
      ..stop()
      ..value = 1;
    if (mounted) setState(() {});
  }

  static double _shortestArcDelta(double from, double to) =>
      ((to - from + 540) % 360) - 180;

  static double _bearingDeg(double fromLat, double fromLng, double toLat, double toLng) {
    final dLng = _rad(toLng - fromLng);
    final latA = _rad(fromLat);
    final latB = _rad(toLat);
    final y = math.sin(dLng) * math.cos(latB);
    final x =
        math.cos(latA) * math.sin(latB) -
        math.sin(latA) * math.cos(latB) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _rad(double deg) => deg * math.pi / 180;

  static _LatLngPair _pair(HopGeoPoint p) => _LatLngPair(p.lat, p.lng);

  /// Haversine distance in meters — replaces latlong2's Distance helper.
  static double _haversineMeters(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // --- Camera choreography ------------------------------------------------

  CameraPosition _initialCameraPosition() {
    final intent = widget.cameraIntent;
    final fallback = widget.carPosition ??
        (widget.pins.isNotEmpty ? widget.pins.first.point : null) ??
        (widget.track?.points.isNotEmpty ?? false
            ? widget.track!.points.first
            : const HopGeoPoint(0, 0));
    final center = switch (intent) {
      FitPoints(:final points) when points.isNotEmpty => points.first,
      FitPoints() => fallback,
      FollowPoint(:final target) => target,
      SettleOn(:final point) => point,
    };
    return CameraPosition(
      target: LatLng(center.lat, center.lng),
      zoom: _pointZoom,
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  void _onStyleLoaded() {
    _mapReady = true;
    _rebuildRoute();
    _rebuildPins();
    _applyIntent(force: true);
  }

  void _onMapClick(math.Point<double> point, LatLng coordinates) {
    if (widget.interactive) {
      widget.onUserGesture();
    }
  }

  /// Picker mode: the camera settled after a gesture — report the centre so a
  /// host can reverse-geocode the point under its fixed centre pin.
  void _onCameraIdle() {
    final cb = widget.onCameraIdle;
    final pos = _controller?.cameraPosition;
    if (cb == null || pos == null) return;
    cb(HopGeoPoint(pos.target.latitude, pos.target.longitude));
  }

  void _applyIntent({bool force = false}) {
    if (!widget.interactive || !widget.follow || !_mapReady) return;
    final ctrl = _controller;
    if (ctrl == null) return;

    switch (widget.cameraIntent) {
      case FitPoints(:final points):
        if (points.isEmpty) return;
        if (points.length == 1) {
          _aim(ctrl, _pair(points.first));
        } else {
          final bounds = _boundsFrom(points);
          ctrl.animateCamera(
            CameraUpdate.newLatLngBounds(
              bounds,
              left: _fitPaddingPx,
              right: _fitPaddingPx,
              top: _fitPaddingPx,
              bottom: _fitPaddingPx,
            ),
          );
          _lastAimed = null;
          _lastAimedAt = clock.now();
        }
      case FollowPoint(:final target):
        final dest = _pair(target);
        if (!force && !_shouldReAim(dest)) return;
        _aim(ctrl, dest);
      case SettleOn(:final point):
        _aim(ctrl, _pair(point));
    }
  }

  bool _shouldReAim(_LatLngPair dest) {
    final aimed = _lastAimed;
    final aimedAt = _lastAimedAt;
    if (aimed == null || aimedAt == null) return true;
    final drifted =
        _haversineMeters(aimed.lat, aimed.lng, dest.lat, dest.lng) >
        _reAimDistanceMeters;
    final elapsed =
        clock.now().difference(aimedAt) >=
        context.hoppin.motion.mapCameraDebounce;
    return drifted || elapsed;
  }

  void _aim(MapLibreMapController ctrl, _LatLngPair dest) {
    ctrl.animateCamera(
      CameraUpdate.newLatLng(LatLng(dest.lat, dest.lng)),
    );
    _lastAimed = dest;
    _lastAimedAt = clock.now();
  }

  static LatLngBounds _boundsFrom(List<HopGeoPoint> points) {
    var minLat = points.first.lat;
    var maxLat = points.first.lat;
    var minLng = points.first.lng;
    var maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // --- Annotation management ----------------------------------------------

  Future<void> _rebuildRoute() async {
    final ctrl = _controller;
    if (ctrl == null || !_mapReady) return;

    if (_routeLine != null) {
      await ctrl.removeLine(_routeLine!);
      _routeLine = null;
    }

    final track = widget.track;
    if (track == null || track.points.length < 2) return;

    if (!mounted) return;
    final colors = context.hoppin.colors;
    _routeLine = await ctrl.addLine(
      LineOptions(
        geometry: [
          for (final p in track.points) LatLng(p.lat, p.lng),
        ],
        lineColor: _colorHex(colors.accent),
        lineWidth: 4.0,
        lineJoin: 'round',
      ),
    );
  }

  Future<void> _rebuildPins() async {
    final ctrl = _controller;
    if (ctrl == null || !_mapReady) return;

    if (_pinCircles.isNotEmpty) {
      await ctrl.removeCircles(_pinCircles);
      _pinCircles.clear();
    }

    if (widget.pins.isEmpty) return;

    if (!mounted) return;
    final colors = context.hoppin.colors;
    for (final pin in widget.pins) {
      final circle = await ctrl.addCircle(
        CircleOptions(
          geometry: LatLng(pin.point.lat, pin.point.lng),
          circleRadius: 9.0,
          circleColor: _pinFillHex(pin.role, colors),
          circleStrokeWidth: _pinStrokeWidth(pin.role),
          circleStrokeColor: _pinStrokeHex(pin.role, colors),
        ),
      );
      _pinCircles.add(circle);
    }
  }

  static String _colorHex(Color c) =>
      '#${c.r.round().toRadixString(16).padLeft(2, '0')}${c.g.round().toRadixString(16).padLeft(2, '0')}${c.b.round().toRadixString(16).padLeft(2, '0')}';

  static String _pinFillHex(HopMapPinRole role, HoppinColors colors) =>
      switch (role) {
        HopMapPinRole.pickup => _colorHex(colors.card),
        HopMapPinRole.destination => _colorHex(colors.accent),
        HopMapPinRole.objective => _colorHex(colors.accent),
      };

  static double _pinStrokeWidth(HopMapPinRole role) =>
      switch (role) {
        HopMapPinRole.pickup => 3.0,
        HopMapPinRole.destination => 2.0,
        HopMapPinRole.objective => 2.0,
      };

  static String _pinStrokeHex(HopMapPinRole role, HoppinColors colors) =>
      switch (role) {
        HopMapPinRole.pickup => _colorHex(colors.accent),
        HopMapPinRole.destination => _colorHex(colors.card),
        HopMapPinRole.objective => _colorHex(colors.card),
      };

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.hoppin.colors;
    // tileProvider != null is the test-isolation seam: skip the MapLibreMap
    // (a platform view) so tests run headlessly. A GestureDetector stands in
    // for MapLibre's onMapClick so gesture-pause tests still work.
    final mapWidget = widget.tileProvider != null
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: widget.interactive
                ? (_) => widget.onUserGesture()
                : null,
            child: ColoredBox(color: colors.canvas),
          )
        : MapLibreMap(
            initialCameraPosition: _initialCameraPosition(),
            styleString: _styleString ?? _buildStyleString(
              Theme.of(context).brightness == Brightness.dark,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapClick: _onMapClick,
            onCameraIdle: widget.onCameraIdle == null ? null : _onCameraIdle,
            trackCameraPosition: widget.onCameraIdle != null,
            scrollGesturesEnabled: widget.interactive,
            zoomGesturesEnabled: widget.interactive,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            compassEnabled: false,
            logoEnabled: false,
            attributionButtonPosition: null,
          );

    return RepaintBoundary(
      child: IgnorePointer(
        ignoring: !widget.interactive,
        child: Stack(
          children: [
            Positioned.fill(child: mapWidget),
            // Car marker overlay — pure Flutter widget, fully introspectable
            // by tests. The AnimatedBuilder rebuilds only this layer as the
            // tween runs; tiles and pin/route annotations are unaffected.
            AnimatedBuilder(
              animation: _marker,
              builder: (context, _) {
                final tween = _carTween;
                if (tween == null) return const SizedBox.shrink();
                final pos = tween.evaluate(_marker);
                return HopMapCarMarker(
                  key: HopMap.carMarkerKey,
                  lat: pos.lat,
                  lng: pos.lng,
                  headingDeg: _headingTween?.evaluate(_marker) ?? 0,
                  colors: colors,
                  size: _carSize,
                );
              },
            ),
            // OSM attribution — required by tile policy, visible in both
            // themes, hand-built so it wraps safely on the compact inset.
            Align(
              alignment: Alignment.bottomRight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.card.withValues(alpha: 0.8),
                  borderRadius:
                      const BorderRadius.only(topLeft: Radius.circular(4)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: context.hoppin.type.labelSmall.copyWith(
                      color: colors.textMid,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The car marker Flutter overlay widget.
///
/// Stores [lat]/[lng] as public fields so tests can read the currently shown
/// position without going through MapLibre's async native layer:
/// ```dart
/// final marker = tester.widget<HopMapCarMarker>(find.byKey(HopMap.carMarkerKey));
/// expect(marker.lat, closeTo(expectedLat, 1e-9));
/// ```
///
/// Rendering: centered in the Stack (the camera follow intent keeps the car
/// near the screen centre during live tracking).
class HopMapCarMarker extends StatelessWidget {
  const HopMapCarMarker({
    required this.lat,
    required this.lng,
    required this.headingDeg,
    required this.colors,
    required this.size,
    super.key,
  });

  final double lat;
  final double lng;
  final double headingDeg;
  final HoppinColors colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Transform.rotate(
          angle: headingDeg * math.pi / 180,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
              border: Border.all(color: colors.hairline, width: 1.5),
            ),
            child: Icon(
              Icons.navigation_rounded,
              size: 16,
              color: colors.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}
