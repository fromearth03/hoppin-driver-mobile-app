import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// Size ramp for [PlateChip].
enum PlateSize {
  /// Inline size — matched cards, receipts, history rows.
  md,

  /// Hero size — the live-trip and matched-moment plate.
  lg,
}

/// THE Hoppin signature motif: a vehicle registration rendered as a real UK
/// number plate — yellow rear plate in the light themes, white front plate
/// in the dark themes, GeistMono w600 characters, always uppercase.
///
/// This is the find-your-car element; it appears on the matched card, live
/// trip, receipt, and history detail. No EU band, no emblem — crafted
/// restraint.
class PlateChip extends StatelessWidget {
  /// Creates a plate chip for registration [reg].
  const PlateChip({required this.reg, this.size = PlateSize.md, super.key});

  /// Vehicle registration; rendered uppercase regardless of input case.
  final String reg;

  /// Chip size — md (16px chars) or lg (24px chars, scaled-up padding).
  final PlateSize size;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final display = reg.toUpperCase();
    final (fontSize, scale) = switch (size) {
      PlateSize.md => (16.0, 1.0),
      PlateSize.lg => (24.0, 1.5),
    };
    return Semantics(
      label: 'Vehicle registration $display',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: (hoppin.spacing.sm + 2) * scale,
          vertical: (hoppin.spacing.xs + 1) * scale,
        ),
        decoration: BoxDecoration(
          color: colors.plateBg,
          borderRadius: BorderRadius.circular(hoppin.radii.plate),
          border: Border.all(
            color: colors.plateText.withValues(alpha: 0.85),
            width: 1.5,
          ),
        ),
        child: Text(
          display,
          style: hoppin.type.plate.copyWith(
            fontSize: fontSize,
            color: colors.plateText,
          ),
        ),
      ),
    );
  }
}
