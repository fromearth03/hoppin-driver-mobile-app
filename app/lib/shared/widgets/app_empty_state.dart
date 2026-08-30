import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// An empty list says what is empty, in its own words. A shared "Nothing
/// here" reads as a bug; "No cancelled trips" reads as an answer.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.textDisabled),
              const SizedBox(height: 16),
              Text(title, style: AppText.heading, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!,
                    style: AppText.bodySecondary, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      );
}
