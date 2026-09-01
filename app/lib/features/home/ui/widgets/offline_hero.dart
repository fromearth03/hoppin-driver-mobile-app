import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';

/// The card an offline driver lands on: the reason to go online, and the
/// button that does it.
///
/// The photograph is the design's own — cropped out of the Figma export
/// (the car and skyline, clear of the baked-in text) and anchored right,
/// with a dark scrim running in from the left so the copy stays readable
/// at any card width.
class OfflineHero extends StatelessWidget {
  final VoidCallback? onGoOnline;

  const OfflineHero({super.key, required this.onGoOnline});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        height: 250,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1B1B3A),
          image: const DecorationImage(
            image: AssetImage('assets/brand/offline_hero_photo.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
        ),
        child: Container(
          // The scrim sits between the photo and the copy, so the text
          // keeps its contrast without dimming itself.
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xE01B1B3A),
                Color(0x731B1B3A),
                Colors.transparent,
              ],
              stops: [0, 0.45, 0.8],
            ),
          ),
          child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "You're Offline",
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Go online to start receiving ride requests and earn',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Frosted rather than solid: it sits on a photograph in the
              // design, and a filled button would fight the image behind it.
              Material(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onGoOnline,
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Go Online',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      );
}

/// Shown under the summary while the driver is offline. Static encouragement,
/// not a claim about live demand — nothing on the API reports how many
/// drivers are working nearby, so this must not pretend to.
class MoreRidesCard extends StatelessWidget {
  const MoreRidesCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              height: 66,
              width: 66,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.savings_outlined,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More rides, more earnings!',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Going online now means more ride requests',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// The waiting state. An online driver with no offer yet is not an error and
/// not an empty list — they are simply waiting, and the screen should say so.
class NoBookingsCard extends StatelessWidget {
  final bool isOnline;

  const NoBookingsCard({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.public, size: 76, color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              isOnline ? 'Waiting for ride requests' : 'No upcoming bookings',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isOnline
                  ? 'You will be notified the moment one arrives.'
                  : 'Go online to see ride requests and scheduled bookings '
                      'here',
              style: const TextStyle(
                  fontSize: 15, height: 1.35, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
