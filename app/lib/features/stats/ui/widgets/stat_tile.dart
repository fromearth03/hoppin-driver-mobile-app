import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// One figure from the driver's record.
///
/// The design puts a filled circular icon badge on the left and stacks the
/// label above the value on the right, with an optional line beneath.
///
/// The Figma tiles also carry a "+8% vs last month" comparison line under
/// every value. `/drivers/me/stats` returns no period, no history and no
/// deltas, so there is nothing to compute a comparison from — [note] is
/// bound to real values only (a rating count, a star row) and the tiles
/// with no such value simply end after the number.
class StatTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String value;

  /// A real, sourced line under the value. Never a fabricated trend.
  final String? note;

  /// Colour for [note]; defaults to secondary text.
  final Color? noteColour;

  /// Renders a five-star row under the value instead of [note]. Used by the
  /// rating tile, where the stars are drawn from the rating itself.
  final double? stars;

  const StatTile({
    super.key,
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    this.note,
    this.noteColour,
    this.stars,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.surface, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.caption.copyWith(
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                    // "Acceptance Rate" does not fit a half-width tile on one
                    // line at phone widths; wrapping beats "Acceptance R…".
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppText.title.copyWith(fontSize: 21),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (stars != null) ...[
                    const SizedBox(height: 3),
                    _Stars(rating: stars!),
                  ] else if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      note!,
                      style: AppText.caption.copyWith(
                        fontSize: 12,
                        color: noteColour ?? AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

/// Five stars filled to the rating. Drawn from the rating we already show,
/// so it adds no claim the number does not already make.
class _Stars extends StatelessWidget {
  final double rating;
  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          // A 4.7 fills five stars the way the design shows; a 4.2 fills
          // four. Rounding to nearest keeps the row honest to the number
          // printed directly above it.
          final filled = rating.round() > i;
          return Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 14,
              color: filled ? AppColors.warning : AppColors.textDisabled,
            ),
          );
        }),
      );
}
