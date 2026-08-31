import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ride.dart';

/// Who the driver is collecting, with the two ways to reach them.
///
/// Full identity is correct here: the driver has accepted and is about to
/// meet a stranger. Withholding applies only before accept/decline.
class RiderCard extends StatelessWidget {
  final Rider rider;
  final int chatUnread;

  /// The ride's support reference, printed under the name rather than on its
  /// own line — it is the first thing support asks for and costs no height
  /// here.
  final String? rideRef;
  final VoidCallback? onCall;
  final VoidCallback? onChat;

  const RiderCard({
    super.key,
    required this.rider,
    this.chatUnread = 0,
    this.rideRef,
    this.onCall,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.border,
              backgroundImage:
                  rider.avatarUrl == null ? null : NetworkImage(rider.avatarUrl!),
              child: rider.avatarUrl == null
                  ? const Icon(Icons.person, color: AppColors.textSecondary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rider.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        // A rider with no ratings yet shows an em dash;
                        // "0.0" would read as an awful passenger.
                        rider.rating == null
                            ? '—'
                            : '${rider.rating!.toStringAsFixed(1)} (${rider.ratingCount})',
                        style: AppText.caption,
                      ),
                      if (rideRef != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(rideRef!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // The design draws these as two solid round buttons. Chat leads,
            // because it is the one that leaves a record on the ride.
            //
            // The design's voice-call button is a plain dialler here: the
            // service has no call bridge, so this is the rider's own number
            // via `tel:`. No presence dot either — nothing reports whether a
            // rider is "Online".
            _RoundAction(
              icon: Icons.chat_bubble,
              color: AppColors.primary,
              badge: chatUnread,
              tooltip: 'Message passenger',
              onPressed: onChat,
            ),
            const SizedBox(width: 8),
            _RoundAction(
              icon: Icons.phone,
              color: AppColors.positive,
              tooltip: 'Call passenger',
              onPressed: onCall,
            ),
          ],
        ),
      );
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int badge;
  final String tooltip;
  final VoidCallback? onPressed;

  const _RoundAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.badge = 0,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Tooltip(
                message: tooltip,
                child: SizedBox(
                  height: 46,
                  width: 46,
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
          if (badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppColors.negative,
                  shape: BoxShape.circle,
                ),
                child: Text('$badge',
                    style: AppText.caption
                        .copyWith(color: Colors.white, fontSize: 11)),
              ),
            ),
        ],
      );
}
