import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/app_buttons.dart';
import '../../data/models/pending_offer.dart';

/// Below this, the question costs more than it saves.
///
/// A decline is final — the offer is suppressed and dispatch moves on — so
/// it deserves a confirmation. But an offer with seconds left is a different
/// situation: spending one of them reading a dialog is how a driver loses a
/// ride they actually wanted. Under the threshold the tap is taken at face
/// value.
const declineConfirmThreshold = 8;

/// Asks before a decline throws the job away.
///
/// Decline sits directly under Accept and is the full width of the card, so
/// a mis-tap is easy and costs the driver the fare with no way back: the
/// offer id is suppressed the moment it resolves and the same ride is never
/// offered to them again.
///
/// Returns true when the driver meant it. Never returns null — a dismissed
/// barrier is a "keep it", which is the safe reading of an ambiguous tap.
Future<bool> confirmDecline(BuildContext context, PendingOffer offer) async {
  if (offer.secondsRemaining <= declineConfirmThreshold) return true;

  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 96,
              width: 96,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_taxi_outlined,
                  size: 42, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 22),
            Text('Decline this ride?',
                style: AppText.title.copyWith(fontSize: 22),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'You will not be offered this ${offer.fare.format()} job '
              'again, and it goes to another driver.',
              style: AppText.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),
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
                      child: const Text('Keep it'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: AppButtons.primary().copyWith(
                        backgroundColor:
                            const WidgetStatePropertyAll(AppColors.negative),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Decline'),
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

  return answer ?? false;
}
