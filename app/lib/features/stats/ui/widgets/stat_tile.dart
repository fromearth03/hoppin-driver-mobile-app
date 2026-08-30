import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

class StatTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final String? note;

  const StatTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    this.note,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tint, size: 22),
            const SizedBox(height: 10),
            Text(label, style: AppText.caption),
            const SizedBox(height: 2),
            Text(value, style: AppText.title),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(note!, style: AppText.caption),
            ],
          ],
        ),
      );
}
