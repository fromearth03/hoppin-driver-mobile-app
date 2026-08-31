import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/waiting_policy.dart';

/// Formats a second count as MM:SS, the clock both the waiting timer and the
/// cancel-window countdown draw.
String clockOf(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final m = (safe ~/ 60).toString().padLeft(2, '0');
  final s = (safe % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Rebuilds its child once a second. Every countdown on this screen needs
/// exactly this and nothing else, so they share one ticker rather than each
/// carrying their own State.
class Ticking extends StatefulWidget {
  final WidgetBuilder builder;

  const Ticking({super.key, required this.builder});

  @override
  State<Ticking> createState() => _TickingState();
}

class _TickingState extends State<Ticking> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// The left half of the waiting sheet: a label over a large running clock,
/// exactly as the design draws it beside the Start Trip button.
///
/// The clock counts the free window *down* while it lasts, then counts the
/// charged time *up* — a single number that always answers the question the
/// waiting passenger is about to ask. The charging terms sit underneath in
/// small type, because a driver who cannot see the rate cannot explain it.
class WaitingTimer extends StatelessWidget {
  final WaitingPolicy policy;

  const WaitingTimer({super.key, required this.policy});

  @override
  Widget build(BuildContext context) => Ticking(
        builder: (context) {
          final billable = policy.isBillable;
          final seconds = billable
              ? DateTime.now().toUtc().difference(policy.billableFrom!).inSeconds
              : policy.freeSecondsRemaining;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                billable ? 'Charged waiting' : 'Waiting Timer',
                style: AppText.caption,
              ),
              const SizedBox(height: 2),
              Text(
                '${clockOf(seconds)} min',
                style: AppText.title.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  color: billable ? AppColors.warning : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                billable
                    ? 'Charged at ${policy.perMinutePence.format()} per minute.'
                    : 'Free waiting, then ${policy.perMinutePence.format()} per minute.',
                style: AppText.caption.copyWith(fontSize: 12),
              ),
            ],
          );
        },
      );
}
