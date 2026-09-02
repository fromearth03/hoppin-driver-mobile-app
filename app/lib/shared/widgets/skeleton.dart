import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// The placeholder a screen shows while its first read is in flight.
///
/// A centred spinner on an empty page tells the driver nothing about what is
/// coming and makes every screen feel the same length. A skeleton in the
/// shape of the real content reads as "this is nearly here", and because it
/// occupies the same space the finished rows will, the page does not jump
/// when they land.
///
/// Only for a genuine first load. Once a screen has data, revisits keep the
/// old rows on screen while a fresh read overtakes them — a skeleton there
/// would be a step backwards, hiding good data behind a placeholder.
class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? radius;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => Opacity(
          // Breathing rather than sliding: a shimmer sweep costs a shader
          // pass per frame on every placeholder, and half these screens draw
          // a dozen at once on the oldest handsets in the fleet.
          opacity: 0.4 + _pulse.value * 0.35,
          child: Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: widget.radius ?? BorderRadius.circular(6),
            ),
          ),
        ),
      );
}

/// One card's worth of placeholder: a title line, two shorter lines under it,
/// and a value on the right — the shape almost every list row in the app
/// takes.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 15, width: 150),
                  SizedBox(height: 10),
                  SkeletonBox(height: 12, width: 110),
                  SizedBox(height: 8),
                  SkeletonBox(height: 12, width: 180),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SkeletonBox(
              height: 26,
              width: 64,
              radius: BorderRadius.circular(8),
            ),
          ],
        ),
      );
}

/// A screenful of card placeholders, for the list screens — trips, earnings,
/// documents, notifications, statements.
class SkeletonList extends StatelessWidget {
  final int rows;

  const SkeletonList({super.key, this.rows = 5});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(top: 16),
        // The placeholder must never scroll: it stands in for content whose
        // real length is not known yet, and a bouncing empty page under the
        // driver's thumb reads as a broken screen.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < rows; i++) const SkeletonCard(),
        ],
      );
}
