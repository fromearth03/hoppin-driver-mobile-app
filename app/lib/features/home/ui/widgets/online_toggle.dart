import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class OnlineToggle extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool>? onChanged;

  const OnlineToggle({super.key, required this.isOnline, this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOnline ? 'Online' : 'Offline',
              style: AppText.heading.copyWith(
                color: isOnline ? AppColors.positive : AppColors.textSecondary,
              ),
            ),
            Switch(
              value: isOnline,
              onChanged: onChanged,
              activeTrackColor: AppColors.positive,
            ),
          ],
        ),
      );
}
