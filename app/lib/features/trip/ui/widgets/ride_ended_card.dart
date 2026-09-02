import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/app_buttons.dart';

/// What the driver sees when the job ended without them ending it.
///
/// A rider cancellation, an admin cancellation and a ride that simply lapsed
/// all reach the app as `cancelled` — the service has no separate `expired`
/// status. Whichever it was, the live map is now the wrong screen: it would
/// keep the driver navigating to a pickup that no longer exists, with an
/// Arrive button the server would refuse.
///
/// The ride carries no cancellation reason, so this states the fact and does
/// not guess at a cause. The one action is the way back to work.
class RideEndedCard extends StatelessWidget {
  final String? rideRef;
  final VoidCallback onDone;

  const RideEndedCard({super.key, this.rideRef, required this.onDone});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 76,
                  width: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.negative.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_busy,
                      size: 38, color: AppColors.negative),
                ),
                const SizedBox(height: 20),
                Text('This ride was cancelled',
                    textAlign: TextAlign.center, style: AppText.heading),
                const SizedBox(height: 10),
                Text(
                  'The job ended before you could finish it. Nothing else is '
                  'needed from you — you can pick up the next one.',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.textSecondary),
                ),
                if (rideRef != null) ...[
                  const SizedBox(height: 16),
                  Text('Ride $rideRef',
                      textAlign: TextAlign.center, style: AppText.caption),
                ],
                const SizedBox(height: 28),
                AppButton(
                  label: 'Back to Home',
                  style: AppButtons.primary(),
                  onPressed: onDone,
                ),
              ],
            ),
          ),
        ),
      );
}
