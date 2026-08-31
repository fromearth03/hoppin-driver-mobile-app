import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// Takes the driver back to a trip that is still running.
///
/// The trip screen is otherwise reachable only from the offer that started
/// it, so a driver who force-quits or gets killed by the OS mid-job has no
/// route back to Arrive, Start or Complete — with a passenger in the car.
class ActiveTripBanner extends StatelessWidget {
  final VoidCallback onResume;

  const ActiveTripBanner({super.key, required this.onResume});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.positive),
        ),
        // The tile paints its ink on the nearest Material, so the background
        // belongs here rather than on the box — on a coloured DecoratedBox
        // the tap would have no visible feedback at all.
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: const Icon(Icons.navigation_outlined,
                color: AppColors.positive),
            title: const Text('Trip in progress', style: AppText.body),
            subtitle:
                const Text('Tap to return to it', style: AppText.caption),
            trailing: const Icon(Icons.chevron_right),
            onTap: onResume,
          ),
        ),
      );
}
