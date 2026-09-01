import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../../auth/logic/auth_controller.dart';
import '../../../home/logic/home_controller.dart';

/// The logout confirmation from the design: a centred card with a close
/// button, an image, the question, and Cancel beside Logout.
///
/// The design's illustration ("See you again!") is a bespoke Figma asset
/// that does not ship with the app, so the circle holds the wave icon at the
/// same size and position rather than leaving a hole in the layout.
Future<void> showLogoutDialog(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textSecondary, size: 24),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ),
            Container(
              height: 150,
              width: 150,
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.waving_hand_outlined,
                  size: 56, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 24),
            Text('Are you logging out?',
                style: AppText.title.copyWith(fontSize: 24),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              "Whenever you're ready to get back on the road, we'll be here.",
              style: AppText.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.textSecondary,
                        textStyle: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: AppButtons.primary(),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Logout'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;
  // The home machinery (offer poll, GPS beat) belongs to the session.
  // signOut only flips auth state; without this a logged-out app keeps
  // reporting the driver's location on a dead token.
  ref.invalidate(homeControllerProvider);
  await ref.read(authControllerProvider.notifier).signOut();
  if (!context.mounted) return;
  context.go(Routes.signIn);
}
