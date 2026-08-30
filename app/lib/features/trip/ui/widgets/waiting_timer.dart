import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/waiting_policy.dart';

/// How long the driver has been waiting, and — the part that matters — when
/// waiting starts costing the rider money. A bare count-up leaves the driver
/// unable to answer the one question a waiting passenger asks.
class WaitingTimer extends StatefulWidget {
  final WaitingPolicy policy;

  const WaitingTimer({super.key, required this.policy});

  @override
  State<WaitingTimer> createState() => _WaitingTimerState();
}

class _WaitingTimerState extends State<WaitingTimer> {
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

  static String _clock(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final policy = widget.policy;
    final billable = policy.isBillable;
    final remaining = policy.freeSecondsRemaining;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (billable ? AppColors.warning : AppColors.info)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(billable ? Icons.timer : Icons.schedule,
              color: billable ? AppColors.warning : AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              billable
                  ? 'Waiting time is being charged at '
                      '${policy.perMinutePence.format()} per minute.'
                  : '${_clock(remaining)} of free waiting left, then '
                      '${policy.perMinutePence.format()} per minute.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
