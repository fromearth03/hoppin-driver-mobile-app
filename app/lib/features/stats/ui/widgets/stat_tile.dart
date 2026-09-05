import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../shared/widgets/glass_card.dart';

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

  /// The tile's real height, so the grid reserves exactly what it draws.
  ///
  /// A grid row taller than its tiles is invisible until it adds up: four
  /// tiles over two rows left a band of empty ground above the section
  /// beneath. Measured rather than guessed, and only the text scales — the
  /// badge and the padding are fixed.
  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    const badge = 38.0 + 10.0; // badge and its gap
    const padding = 14.0 * 2; // GlassCard's own inset
    final label = scaler.scale(13) * 1.3;
    final value = scaler.scale(24) * 1.1;
    // Every tile on this screen carries a third line (stars or a note), so
    // reserving it keeps the two rows the same height.
    final third = scaler.scale(11.5) * 1.3 + 4;
    return badge + padding + label + value + third + 6;
  }

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(14),
        radius: 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge on its own row rather than beside the text. Sharing the
            // row cost the label ~56pt of a half-width tile, which is what
            // broke "Cancellation Rate" across a line mid-word.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tint.withValues(alpha: 0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.surface, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppText.caption.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              // Full tile width now, so one line holds every label the
              // screen actually uses.
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppText.title.copyWith(fontSize: 24, height: 1.1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (stars != null) ...[
              const SizedBox(height: 4),
              _Stars(rating: stars!),
            ] else if (note != null) ...[
              const SizedBox(height: 3),
              Text(
                note!,
                style: AppText.caption.copyWith(
                  fontSize: 11.5,
                  color: noteColour ?? AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
              color: filled ? AppColors.gold : AppColors.textDisabled,
            ),
          );
        }),
      );
}
