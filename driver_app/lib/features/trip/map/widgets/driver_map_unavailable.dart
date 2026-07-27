import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The DRIVER's designed unavailable-state for the nav canvas — seams #41
/// (`driverPosition`) and #17 (`rideGeo`), which both answer `null` on every
/// live request.
///
/// WHAT THIS REPLACES. `map_view.dart` returned `SizedBox.shrink()` on
/// [MapPhase.hidden] — a BLANK. On live that is the only branch that ever
/// runs, so every live trip rendered an empty canvas where the map should be:
/// no map, no route, no explanation. The driver was navigating a passenger
/// somewhere with a nav-less trip runner and the app never said why.
///
/// WHY THIS IS NOT THE RIDER'S RUNG. The rider's `RouteOnlyMapState` says "we
/// can't show your driver moving yet — here's the route." It can say that
/// because the rider's map still has a route to draw. The driver's does not:
/// #17 means there is no geometry AND no coordinates, so there is nothing to
/// draw at all. Same gap, different product, different honest sentence. A
/// shared generic widget would make both disclosures less honest, not more.
///
/// 🔴 WHY IT DOES NOT PRINT AN ADDRESS. The Phase-0 red list expected this rung
/// to render the pickup/dropoff address text "which the driver DOES have, from
/// the ride payload". Verified against HEAD: THE DRIVER DOES NOT HAVE IT.
/// `Ride` (`GET /rides/:id`) carries ids, a status and timestamps — no address,
/// no coordinates. The only address text in the driver app is
/// `TripRiderContext.pickupLabel`, and that is seam #6, which is ALSO null on
/// live. So there is no address to print, and printing a placeholder where an
/// address belongs would be the precise lie this rung exists to delete. It
/// names what is missing instead.
///
/// THE FORWARD EXIT. A disclosure that strands the driver is only half-honest.
/// This rung is a BACKGROUND layer: the trip runner's persistent card — the
/// stage spine, the rider row, and the primary action (Arrived / slide-to-start
/// / slide-to-complete / Done) — renders ON TOP of it and stays fully
/// reachable. The driver can always finish the trip. The rung says so.
class DriverMapUnavailable extends StatelessWidget {
  /// Creates the #41/#17 driver nav-canvas degrade rung.
  const DriverMapUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return ColoredBox(
      color: colors.canvas,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hoppin.spacing.gutter),
          // 🔴 THIS RUNG OWNS THE TOP BAND, NOT THE WHOLE CANVAS.
          //
          // It is a BACKGROUND layer: the trip runner's phase headline sits
          // over its top and the persistent card covers the bottom of the same
          // screen. Centring in the full viewport put this copy underneath both
          // — the reported collision was "Head to pickup" landing on this
          // block's own text, and on short phones the closing line ("Your trip
          // controls below still work") disappeared behind the card entirely.
          //
          // Sizing to the upper band and centring WITHIN it is what actually
          // separates the layers, rather than nudging paddings until one
          // screen size happens to look right. `heightFactor` scales with the
          // viewport, so the relationship holds on every phone instead of only
          // the one it was eyeballed on.
          child: Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: _bandHeightFactor,
              child: Padding(
                // Headroom for the phase headline, which is pinned to the top
                // of this same band by the runner above.
                padding: EdgeInsets.only(top: _headlineHeadroom),
                // The band is a BUDGET, and on a short phone the budget is
                // smaller than this rung's natural height. Scrolling inside it
                // keeps every line reachable instead of trading the headline
                // collision for a clipped disclosure — the copy that names the
                // gap is the whole point of the rung.
                child: SingleChildScrollView(
                  child: Column(
                    // Centred inside the band, which clears the headline
                    // pinned above it and the card anchored below it.
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // The dashed frame stands in for the canvas that is not
                      // there — a deliberate, designed absence rather than a
                      // void. It reads as "this pane has no data", which is
                      // exactly what is true.
                      CustomPaint(
                        painter: _AbsentCanvasPainter(colors.hairline),
                        child: SizedBox(
                          height: 96,
                          width: double.infinity,
                          child: Center(
                            child: Icon(
                              Icons.map_outlined,
                              size: 28,
                              color: colors.textMid,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: hoppin.spacing.lg),
                      Text(
                        'No map for this trip',
                        textAlign: TextAlign.center,
                        style: hoppin.type.title.copyWith(color: colors.textHi),
                      ),
                      SizedBox(height: hoppin.spacing.sm),
                      Text(
                        'The ride service sends us no route and no live '
                        'position, so we have nothing to draw. Use your own '
                        'navigation app to get there.',
                        textAlign: TextAlign.center,
                        style: hoppin.type.bodySmall
                            .copyWith(color: colors.textMid),
                      ),
                      SizedBox(height: hoppin.spacing.md),
                      // The forward exit, stated: the trip is still fully
                      // runnable from the card below. Nothing on this screen
                      // is a dead end.
                      Text(
                        'Your trip controls below still work.',
                        textAlign: TextAlign.center,
                        style: hoppin.type.labelSmall
                            .copyWith(color: colors.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The share of the viewport this rung is allowed to occupy, measured from
  /// the top. The runner's persistent card takes the rest; keeping the rung
  /// inside this band is what stops the two layers from colliding on a short
  /// phone.
  static const double _bandHeightFactor = 0.52;

  /// Clearance left at the top of the band for the runner's phase headline,
  /// which is pinned there and overlays this layer. Sized for the 28pt
  /// headline plus its own top inset.
  static const double _headlineHeadroom = 56;
}

/// The dashed placeholder frame. Painted rather than composed so the "absent
/// canvas" reads as one deliberate mark, not a stack of boxes.
class _AbsentCanvasPainter extends CustomPainter {
  const _AbsentCanvasPainter(this.stroke);

  final Color stroke;

  static const double _dash = 6;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(12),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, (d + _dash).clamp(0.0, metric.length)),
          paint,
        );
        d += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_AbsentCanvasPainter oldDelegate) =>
      oldDelegate.stroke != stroke;
}
