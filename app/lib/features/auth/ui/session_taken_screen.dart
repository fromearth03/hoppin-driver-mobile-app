import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/auth/session_lost.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔴 THE REASON DECIDES THE COPY. This screen said "signed in on another
    // device" for every ended session, which sends a deleted driver hunting
    // for a phone that does not exist, and offers a banned one a password
    // reset that will not help. Same screen, three honest versions.
    final reason =
        ref.watch(sessionLostProvider) ?? SessionEndReason.replaced;
    final replaced = reason == SessionEndReason.replaced;

    final (icon, tint, title, detail) = switch (reason) {
      SessionEndReason.replaced => (
          Icons.phonelink_lock_outlined,
          AppColors.warning,
          'You were signed out',
          'Your account signed in on another device. Only one device can be '
              'signed in at a time, so this one was signed out.',
        ),
      SessionEndReason.deleted => (
          Icons.person_off_outlined,
          AppColors.negative,
          'This account has been deleted',
          'The account and its data have been erased. Logging in again will '
              'not work. Contact support if this was not meant to happen.',
        ),
      SessionEndReason.blocked => (
          Icons.block,
          AppColors.negative,
          'You cannot drive right now',
          'This account or device has been blocked. Support can tell you why '
              'and what happens next.',
        ),
    };

    return _build(context, ref, icon, tint, title, detail, replaced);
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    IconData icon,
    Color tint,
    String title,
    String detail,
    bool replaced,
  ) =>
      Scaffold(
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
                        color: tint.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 42, color: tint),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.title.copyWith(fontSize: 23),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style:
                        AppText.body.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 22),
                  // The security path, stated plainly and kept quiet. Most of
                  // the time this is the driver's own second phone; leading
                  // with alarm would train them to ignore it.
                  //
                  // Only for a replaced session: nobody took a deleted or
                  // blocked account, so telling that driver to change their
                  // password sends them to fix a problem they do not have.
                  if (replaced) Container(
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
                            'logging back in — whoever logged in has your '
                            'account until you do.',
                            style: AppText.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  AppButton(
                    // A deleted or blocked account cannot log back in, so the
                    // button says what it can actually do.
                    label: replaced ? 'Log in again' : 'Back to log in',
                    style: AppButtons.primary(),
                    onPressed: () => _leave(context, ref, Routes.signIn),
                  ),
                  if (replaced) ...[
                    const SizedBox(height: 12),
                    AppButton(
                      label: "This wasn't me — change password",
                      style: AppButtons.outlined(),
                      onPressed: () =>
                          _leave(context, ref, Routes.forgotPassword),
                    ),
                  ],
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
