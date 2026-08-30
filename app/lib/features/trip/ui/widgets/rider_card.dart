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
  final VoidCallback? onCall;
  final VoidCallback? onChat;

  const RiderCard({
    super.key,
    required this.rider,
    this.chatUnread = 0,
    this.onCall,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.border,
                backgroundImage: rider.avatarUrl == null
                    ? null
                    : NetworkImage(rider.avatarUrl!),
                child: rider.avatarUrl == null
                    ? const Icon(Icons.person, color: AppColors.textSecondary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rider.fullName, style: AppText.heading),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          // A rider with no ratings yet shows an em dash;
                          // "0.0" would read as an awful passenger.
                          rider.rating == null
                              ? '—'
                              : '${rider.rating!.toStringAsFixed(1)} (${rider.ratingCount})',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone, color: AppColors.positive),
                onPressed: onCall,
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline,
                        color: AppColors.primary),
                    onPressed: onChat,
                  ),
                  if (chatUnread > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.negative,
                          shape: BoxShape.circle,
                        ),
                        child: Text('$chatUnread',
                            style: AppText.caption
                                .copyWith(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}
