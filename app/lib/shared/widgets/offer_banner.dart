import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../features/home/logic/home_controller.dart';
import '../../features/trip/ui/widgets/waiting_timer.dart' show Ticking;

/// The in-app half of the offer alert: a driver reading their earnings or
/// uploading a document is still on shift, and the offer poll keeps running
/// behind every page — but the card it feeds lives on Home. This banner
/// surfaces that offer wherever the driver actually is, with the countdown,
/// and one tap lands them on the card itself.
///
/// Renders nothing on Home (the full card is already there) and nothing
/// when no offer is pending, so it costs no height anywhere else.
class OfferBanner extends ConsumerWidget {
  final String currentPath;

  const OfferBanner({super.key, required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = ref.watch(
      homeControllerProvider.select((s) => s.valueOrNull?.offer),
    );
    final show =
        offer != null && !offer.hasExpired && currentPath != Routes.home;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
      child: !show
          ? const SizedBox.shrink()
          : SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 8,
                  shadowColor: Colors.black38,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.go(Routes.home),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 40,
                            width: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_taxi,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'New ride request',
                                  style: TextStyle(
                                    fontFamily: AppText.fontFamily,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${offer.fare.format()} · tap to view',
                                  style: const TextStyle(
                                    fontFamily: AppText.fontFamily,
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // The same clock the offer card runs — an offer
                          // seen from the Stats page lapses just as fast.
                          Ticking(
                            builder: (_) => Text(
                              '${offer.secondsRemaining}s',
                              style: TextStyle(
                                fontFamily: AppText.fontFamily,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: offer.secondsRemaining <= 10
                                    ? const Color(0xFFFFB4A9)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
