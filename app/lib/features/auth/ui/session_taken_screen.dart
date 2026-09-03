import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../logic/auth_controller.dart';

/// Shown when this device loses the account's single live session.
///
/// The service allows one session per driver, so signing in elsewhere kicks
/// this one out and every call afterwards answers 401. That is an ordinary
/// event — a driver moving to their second phone — and a serious one: it is
/// also exactly what an account takeover looks like from this side.
///
/// The app cannot tell those apart. `SESSION_REPLACED` carries no device,
/// time or place (see docs/backend-asks.md), so this screen states what
/// happened, offers the innocent path first, and puts the password change
/// within reach without claiming a break-in occurred.
class SessionTakenScreen extends ConsumerWidget {
  const SessionTakenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      height: 92,
                      width: 92,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phonelink_lock_outlined,
                          size: 42, color: AppColors.warning),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'You were signed out',
                    textAlign: TextAlign.center,
                    style: AppText.title.copyWith(fontSize: 23),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your account signed in on another device. Only one '
                    'device can be signed in at a time, so this one was '
                    'signed out.',
                    textAlign: TextAlign.center,
                    style:
                        AppText.body.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 22),
                  // The security path, stated plainly and kept quiet. Most of
                  // the time this is the driver's own second phone; leading
                  // with alarm would train them to ignore it.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: AppColors.textSecondary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "If this wasn't you, change your password before "
                            'signing back in — whoever signed in has your '
                            'account until you do.',
                            style: AppText.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  AppButton(
                    label: 'Sign in again',
                    style: AppButtons.primary(),
                    onPressed: () => _leave(context, ref, Routes.signIn),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: "This wasn't me — change password",
                    style: AppButtons.outlined(),
                    onPressed: () =>
                        _leave(context, ref, Routes.forgotPassword),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  /// Clears whatever is left of the dead session before going anywhere.
  ///
  /// The tokens on this device are already worthless, but leaving them in
  /// place means the next launch resumes into a session the server has
  /// forgotten and 401s its way through the app.
  Future<void> _leave(
      BuildContext context, WidgetRef ref, String route) async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    context.go(route);
  }
}
