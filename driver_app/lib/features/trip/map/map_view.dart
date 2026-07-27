import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'map_builder.dart';
import 'map_state.dart';
import 'widgets/driver_map_unavailable.dart';

/// Dumb render layer of the driver map riblet (DOCS/05, router-free): the
/// full-bleed nav canvas the trip runner mounts BEHIND its morphing card.
/// State in via `ref.watch(tripMapInteractorProvider(rideId))`; the only
/// thing flowing out is the HopMap gesture hook flipping the host-owned
/// follow switch. No navigation, no timers, no demo branches — and no data
/// access: geo arrives through the interactor only.
///
/// MapPhase.hidden — the ONLY phase live mode ever reaches, because both geo
/// seams (#41, #17) answer null on every request — renders the designed
/// [DriverMapUnavailable] rung. It used to render nothing at all.
class DriverTripMap extends ConsumerStatefulWidget {
  const DriverTripMap({required this.rideId, super.key});

  /// The ride this map contextualizes — the interactor's family key.
  final String rideId;

  @override
  ConsumerState<DriverTripMap> createState() => _DriverTripMapState();
}

class _DriverTripMapState extends ConsumerState<DriverTripMap> {
  /// Host-owned follow switch (the HopMap contract): a map gesture pauses
  /// the chase camera; only the recenter chip resumes it.
  bool _follow = true;

  void _pauseFollow() {
    if (!_follow) return;
    setState(() => _follow = false);
  }

  void _resumeFollow() {
    setState(() => _follow = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripMapInteractorProvider(widget.rideId));
    if (state.phase == MapPhase.hidden) {
      // 🔴 Seams #41 (driverPosition) + #17 (rideGeo) — BOTH null on every live
      // request, so this is the ONLY branch that runs on live. It used to
      // return `SizedBox.shrink()`: a blank canvas, on every live trip, with no
      // map, no route and no explanation. It is now the designed rung. The trip
      // controls render on top of it and stay reachable.
      return const DriverMapUnavailable();
    }
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final tileProvider = ref.watch(mapTileProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        HopMap(
          pins: state.pins,
          track: state.track,
          carPosition: state.carPosition,
          carHeading: state.carHeading,
          cameraIntent: state.cameraIntent,
          follow: _follow,
          interactive: true,
          onUserGesture: _pauseFollow,
          userAgentPackageName: 'com.hoppin.driver',
          tileProvider: tileProvider,
        ),
        // Headline legibility over tiles: a paint-level vertical scrim
        // (canvas -> transparent over the top ~30%) — never a blur. It
        // lives with the map, so a hidden map collapses it automatically.
        IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: 0.3,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.canvas,
                      colors.canvas.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Nav chrome: the objective distance chip and (while follow is
        // paused) the recenter chip. Empty regions pass hits to the map.
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: hoppin.spacing.gutter,
              vertical: hoppin.spacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.remainingMeters != null)
                  _ObjectiveChip(
                    label: state.objectiveLabel,
                    meters: state.remainingMeters!,
                  ),
                const Spacer(),
                if (!_follow) _RecenterChip(onTap: _resumeFollow),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The objective distance chip: objective word + remaining distance in
/// GeistMono tabular numerals on a hairline pill — glanceable work context,
/// not navigation.
class _ObjectiveChip extends StatelessWidget {
  const _ObjectiveChip({required this.label, required this.meters});

  final String label;
  final int meters;

  static const double _metersPerMile = 1609.344;

  String get _distance {
    final miles = meters / _metersPerMile;
    return '${miles.toStringAsFixed(1)} mi';
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.hairline),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: hoppin.spacing.md,
          vertical: hoppin.spacing.xs + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: hoppin.type.labelSmall.copyWith(color: colors.textMid),
            ),
            SizedBox(width: hoppin.spacing.sm),
            Text(
              _distance,
              style: hoppin.type.numeralCaption.copyWith(color: colors.textHi),
            ),
          ],
        ),
      ),
    );
  }
}

/// The follow-resume affordance — appears only while a gesture has paused
/// the chase camera; petrol-navy accent on the hairline pill.
class _RecenterChip extends StatelessWidget {
  const _RecenterChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return Material(
      color: colors.card.withValues(alpha: 0.9),
      shape: StadiumBorder(side: BorderSide(color: colors.hairline)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hoppin.spacing.md,
            vertical: hoppin.spacing.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.my_location_rounded, size: 14, color: colors.accent),
              SizedBox(width: hoppin.spacing.xs),
              Text(
                'Recenter',
                style: hoppin.type.labelSmall.copyWith(color: colors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
