import 'package:flutter/foundation.dart';
import 'package:hoppin_ui/hoppin_ui.dart'
    show FitPoints, HopGeoPoint, HopMapCameraIntent, HopMapPin, HopMapTrack;

/// How much of the nav canvas the seams currently support — the same
/// designed degradation ladder as the rider map (06-RESEARCH pattern 4).
enum MapPhase {
  /// Both seams answered null — which is EVERY live request. The canvas
  /// renders the designed [DriverMapUnavailable] rung, never a blank.
  hidden,

  /// Geometry only, no live position (live once gap #17 ships before #41):
  /// objective pin + polyline, no car marker, no chase.
  routeOnly,

  /// Position flowing (demo today; live once gaps #41 + #17 ship): heading
  /// marker, objective route, chase camera, distance chip.
  liveTracking,
}

/// Immutable snapshot of everything the driver trip map renders. One class
/// + a phase enum, hand-rolled in the riblet convention — value-equal so
/// stable 1 Hz ticks (a parked car) never re-emit.
@immutable
class MapState {
  const MapState({
    this.phase = MapPhase.hidden,
    this.pins = const [],
    this.track,
    this.carPosition,
    this.carHeading,
    this.cameraIntent = const FitPoints([]),
    this.objectiveLabel = 'Pickup',
    this.remainingMeters,
    this.destination,
  });

  final MapPhase phase;

  /// The current objective's pin (MAP-04: pickup while heading there,
  /// destination once started) — at most one, objective-role styled.
  final List<HopMapPin> pins;

  /// 🔴 THE HAND-OFF TARGET (OT-16): the current leg's destination — pickup
  /// while heading there, drop-off once started — as a raw lat/lng, so the
  /// Navigate control can build a Google Maps directions URL for it.
  ///
  /// It flips WITH the objective pin, in the same emission. Null whenever there
  /// is no honest destination to hand off to (both geo seams answered null —
  /// EVERY live request today) — and a null destination hides the control, the
  /// same designed degradation the map's own chip uses.
  final HopGeoPoint? destination;

  /// The polyline of the current leg; null when no geometry exists.
  final HopMapTrack? track;

  /// Latest 1 Hz position sample; null hides the car marker.
  final HopGeoPoint? carPosition;

  /// Seam heading in degrees clockwise from north; null lets HopMap fall
  /// back to the marker's own movement bearing.
  final double? carHeading;

  /// What the camera frames: FollowPoint(car) whenever a position exists,
  /// FitPoints(pickup + destination) otherwise.
  final HopMapCameraIntent cameraIntent;

  /// The distance chip's objective word — 'Pickup' or 'Drop-off'. The pin,
  /// track, and this label always flip together.
  final String objectiveLabel;

  /// Distance left along the current leg from the car's position; null
  /// (no honest along-leg figure) hides the chip.
  final int? remainingMeters;

  @override
  bool operator ==(Object other) =>
      other is MapState &&
      other.phase == phase &&
      listEquals(other.pins, pins) &&
      other.track == track &&
      other.carPosition == carPosition &&
      other.carHeading == carHeading &&
      other.cameraIntent == cameraIntent &&
      other.objectiveLabel == objectiveLabel &&
      other.remainingMeters == remainingMeters &&
      other.destination == destination;

  @override
  int get hashCode => Object.hash(
        phase,
        Object.hashAll(pins),
        track,
        carPosition,
        carHeading,
        cameraIntent,
        objectiveLabel,
        remainingMeters,
        destination,
      );
}
