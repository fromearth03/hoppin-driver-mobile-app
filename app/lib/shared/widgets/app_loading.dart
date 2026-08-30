import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

class AppLoading extends StatelessWidget {
  final String? label;
  const AppLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(label!, style: AppText.caption),
            ],
          ],
        ),
      );
}
