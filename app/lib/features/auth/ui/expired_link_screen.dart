import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// The Figma frame draws a spinner and "We're Almost There" for what is a
/// failure. A stalled loader is the one thing a driver should not see when
/// the link is simply dead — this states the outcome and offers the fix.
class ExpiredLinkScreen extends StatelessWidget {
  const ExpiredLinkScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_off,
                      size: 56, color: AppColors.textDisabled),
                  const SizedBox(height: 20),
                  const Text('This link has expired',
                      style: AppText.title, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'Password reset links are valid for a short time. Request a new one and it will arrive in a moment.',
                    style: AppText.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => context.go(Routes.forgotPassword),
                    child: const Text('Request a new link'),
                  ),
                  TextButton(
                    onPressed: () => context.go(Routes.signIn),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
