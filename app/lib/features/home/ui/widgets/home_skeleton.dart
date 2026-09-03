import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/app_skeleton.dart';

/// The cold-start placeholder for Home: the shape of the screen the driver is
/// about to get, rather than a spinner in the middle of nothing.
///
/// Only ever shown when NO state has arrived — a refresh over a screen that
/// already has content keeps the content (see `AsyncView`). So this is the
/// first-launch view, and its job is to make the app feel like it opened
/// rather than like it stalled.
///
/// Mirrors the real layout: the online hero, the three Today tiles, and a
/// card beneath. A placeholder shaped like something else would move the
/// content when it lands, which is worse than a spinner.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        children: [
          // The hero: a big round control with a line of copy under it.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Skeleton(width: 132, height: 132, radius: 66),
                SizedBox(height: 18),
                Skeleton(width: 160, height: 16),
                SizedBox(height: 8),
                Skeleton(width: 220, height: 12),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Today: three figures side by side.
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Expanded(child: _Tile()),
                SizedBox(width: 12),
                Expanded(child: _Tile()),
                SizedBox(width: 12),
                Expanded(child: _Tile()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SkeletonCard(),
        ],
      );
}

/// One Today figure: a small caption over a larger number.
class _Tile extends StatelessWidget {
  const _Tile();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 48, height: 10),
          SizedBox(height: 8),
          Skeleton(width: 68, height: 20),
        ],
      );
}
