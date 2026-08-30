import 'package:flutter/material.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/error_codes.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// Shows mapped copy for a failure. Retry appears only when retrying could
/// actually succeed — offering it for a suspended account teaches the driver
/// the button is a lie.
class AppErrorState extends StatelessWidget {
  final ApiException error;
  final VoidCallback? onRetry;

  const AppErrorState({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final canRetry = onRetry != null && error.isRetryable;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.negative),
            const SizedBox(height: 16),
            Text(errorCopy(error),
                style: AppText.body, textAlign: TextAlign.center),
            if (canRetry) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
