import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ride_stop.dart';
import 'waiting_timer.dart';

/// The multi-stop leg list: what the driver is being paid for, leg by leg.
///
/// The design draws a multi-stop route as A, a "Mid point" and C, with a
/// mileage pill on each leg. This is that, plus the money — a driver asked to
/// make an extra stop needs to see what the extra stop pays.
///
/// Renders nothing on an ordinary single-leg ride, so the trip screen can
/// include it unconditionally.
///
/// It COLLAPSES, because a four-leg route is a tall card on a screen whose
/// other job is showing the road. Folded, it keeps the two things a driver
/// needs at a glance — how many stops and what the trip pays — and hides the
/// per-leg breakdown, which is reading material for a standstill.
class StopsCard extends StatefulWidget {
  final RideStops stops;

  /// Null until the trip is under way. Arrive and depart only mean anything
  /// once the rider is aboard and the driver is working through the stops.
  final void Function(RideStop stop)? onArrive;
  final void Function(RideStop stop)? onDepart;
  final bool busy;

  /// Whether the leg list starts open. Open by default: on a trip the driver
  /// has just accepted, the breakdown is the thing they want to check.
  final bool initiallyExpanded;

  const StopsCard({
    super.key,
    required this.stops,
    this.onArrive,
    this.onDepart,
    this.busy = false,
    this.initiallyExpanded = true,
  });

  @override
  State<StopsCard> createState() => _StopsCardState();
}

class _StopsCardState extends State<StopsCard> {
  late bool _expanded = widget.initiallyExpanded;

  RideStops get stops => widget.stops;
  bool get busy => widget.busy;
  void Function(RideStop)? get onArrive => widget.onArrive;
  void Function(RideStop)? get onDepart => widget.onDepart;

  @override
  Widget build(BuildContext context) {
    if (!stops.multiStop || stops.stops.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The header IS the toggle. A separate chevron button would be a
          // second small target on a screen tapped from the driver's seat;
          // the whole summary row is the affordance instead.
          Semantics(
            button: true,
            label: _expanded
                ? 'Hide the leg breakdown'
                : 'Show the leg breakdown',
            child: InkWell(
              key: const Key('stops-card-toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    const Icon(
                      Icons.alt_route,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stops.stopCount == 1
                            ? '1 stop on this trip'
                            : '${stops.stopCount} stops on this trip',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      stops.total.format(),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_expanded) ...[
            // 🔴 THE NEXT STOP SURVIVES THE FOLD. Everything else in this card
            // is reference; this line is the instruction — where to drive now.
            // Hiding it would make the collapse cost the driver the one fact
            // they opened the card for.
            if (stops.nextStop case final next?) ...[
              const SizedBox(height: 6),
              Text(
                'Next: ${next.label}',
                key: const Key('stops-card-next'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
          if (_expanded) ...[
            const SizedBox(height: 4),
            // The one thing a driver will get wrong unprompted: assuming the
            // platform's cut comes off each leg. It comes off the total, once.
            const Text(
              'Legs are priced separately and added up. Fees come off the total '
              'once, not per leg.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            for (final stop in stops.stops)
              _StopRow(
                stop: stop,
                isNext: stop.seq == stops.nextStop?.seq,
                busy: busy,
                onArrive: onArrive == null ? null : () => onArrive!(stop),
                onDepart: onDepart == null ? null : () => onDepart!(stop),
              ),
            if (!stops.waitingTotal.isZero) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Waiting so far',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    stops.waitingTotal.format(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One leg. The dropoff is listed but never offers arrive or depart: the
/// repository stamps only rows with `kind = 'stop'`, so a button there would
/// call an endpoint that answers 200 and changes nothing.
class _StopRow extends StatelessWidget {
  final RideStop stop;
  final bool isNext;
  final bool busy;
  final VoidCallback? onArrive;
  final VoidCallback? onDepart;

  const _StopRow({
    required this.stop,
    required this.isNext,
    required this.busy,
    this.onArrive,
    this.onDepart,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _marker(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isNext ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              stop.fare.format(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        // The live wait clock, ticking against the server's arrival stamp
        // rather than a timer started on the handset.
        if (stop.isWaiting) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Ticking(
              builder: (context) {
                final waited = DateTime.now()
                    .toUtc()
                    .difference(stop.arrivedAt!.toUtc())
                    .inSeconds;
                return Text(
                  'Waiting ${clockOf(waited < 0 ? 0 : waited)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ],
        if (stop.canWait && (onArrive != null || onDepart != null)) ...[
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.only(left: 32), child: _action()),
        ],
      ],
    ),
  );

  String get _title {
    if (stop.label.isNotEmpty) return stop.label;
    return stop.isDropoff ? 'Dropoff' : 'Stop ${stop.seq + 1}';
  }

  String get _subtitle => [
    stop.distanceLabel,
    if (!stop.waiting.isZero) 'waited ${stop.waiting.format()}',
    // A stop added after accept is worth calling out: it is not the job
    // the driver agreed to.
    if (stop.addedMidTrip) 'added mid-trip',
  ].join(' · ');

  Widget _action() {
    if (stop.isDone) {
      return const Text(
        'Departed',
        style: TextStyle(fontSize: 14, color: AppColors.textDisabled),
      );
    }
    final arrived = stop.isWaiting;
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        key: Key('stop_action_${stop.seq}'),
        onPressed: busy ? null : (arrived ? onDepart : onArrive),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Text(
          arrived ? 'Depart' : 'Arrived at stop',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _marker() {
    final IconData icon;
    final Color colour;
    if (stop.isDropoff) {
      icon = Icons.outlined_flag;
      colour = AppColors.accent;
    } else if (stop.isDone) {
      icon = Icons.check_circle;
      colour = AppColors.positive;
    } else if (stop.isWaiting) {
      icon = Icons.hourglass_top;
      colour = AppColors.warning;
    } else {
      icon = Icons.trip_origin;
      colour = AppColors.textSecondary;
    }
    return Icon(icon, size: 20, color: colour);
  }
}

/// Asks for a label for a stop the driver is adding mid-trip.
///
/// Coordinates are not collected here. The handler rejects a zero lat or lng
/// outright, and a driver cannot type a latitude — so a stop is only ever
/// added at the driver's current position, which the caller supplies.
class AddStopSheet extends StatefulWidget {
  const AddStopSheet({super.key});

  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        builder: (_) => const AddStopSheet(),
      );

  @override
  State<AddStopSheet> createState() => _AddStopSheetState();
}

class _AddStopSheetState extends State<AddStopSheet> {
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Add a stop', style: AppText.title),
        const SizedBox(height: 6),
        const Text(
          'The stop is added at your current location, and every leg is '
          're-priced. The rider is told the fare changed.',
          style: AppText.bodySecondary,
        ),
        const SizedBox(height: 18),
        TextField(
          key: const Key('add_stop_label'),
          controller: _label,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'What is this stop? (optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('add_stop_confirm'),
          onPressed: () => Navigator.of(context).pop(_label.text.trim()),
          child: const Text('Add stop'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Never mind'),
        ),
      ],
    ),
  );
}
