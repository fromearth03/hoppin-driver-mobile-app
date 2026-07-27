import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// Semantic tone of a [StatusPill] — maps onto the matching HoppinColors
/// role and its precomputed subtle tint.
enum PillTone {
  /// Informational — textMid on the card surface with a hairline border.
  neutral,

  /// Lane accent — navy in the revamp.
  accent,

  /// Positive money/status moments (Figma: leading ✓).
  success,

  /// Caution — ochre.
  warn,

  /// Failure/destructive.
  error,
}

/// A fully-rounded (radius 100) status pill: subtle-tint background,
/// role-colour label. The Figma success pill leads with a ✓ tick. Set [dot]
/// for the borderless inline live-trip variant (a role-colour dot before a
/// navy label). Set [numeric] for the tabular ETA/countdown caption.
class StatusPill extends StatelessWidget {
  /// Creates a status pill with [label] in the given [tone].
  const StatusPill({
    required this.label,
    this.tone = PillTone.neutral,
    this.dot = false,
    this.numeric = false,
    super.key,
  });

  /// Pill text.
  final String label;

  /// Semantic tone; picks foreground role and subtle background.
  final PillTone tone;

  /// Render a 6px leading dot in the role colour (borderless inline variant).
  final bool dot;

  /// Use the tabular numeral caption style — for ETA/countdown pills whose
  /// width must not jitter as digits tick. Poppins tabular figures.
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final (fg, bg) = switch (tone) {
      PillTone.neutral => (colors.textMid, colors.card),
      PillTone.accent => (colors.accent, colors.accentSubtle),
      PillTone.success => (colors.success, colors.successSubtle),
      PillTone.warn => (colors.warn, colors.warnSubtle),
      PillTone.error => (colors.error, colors.errorSubtle),
    };

    // The inline dot variant sits borderless with a navy(textHi) label — the
    // Figma "Driver En-route" live-status treatment.
    final inline = dot;
    final labelColor = inline ? colors.textHi : fg;
    final style = numeric
        ? hoppin.type.numeralCaption.copyWith(color: labelColor)
        : hoppin.type.metaSmall.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w500,
          );

    // Success pills lead with the Figma ✓ tick (unless the inline dot is on).
    final showCheck = tone == PillTone.success && !dot;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: hoppin.spacing.sm + 2,
        vertical: hoppin.spacing.xs,
      ),
      decoration: ShapeDecoration(
        color: inline ? Colors.transparent : bg,
        shape: StadiumBorder(
          side: tone == PillTone.neutral && !inline
              ? BorderSide(color: colors.hairline)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            SizedBox(
              width: 6,
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
            ),
            SizedBox(width: hoppin.spacing.xs),
          ] else if (showCheck) ...[
            Icon(Icons.check, size: 14, color: fg),
            SizedBox(width: hoppin.spacing.xs),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }
}
