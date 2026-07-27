import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// A settings/menu list row (Figma: Profile, Support).
///
/// A leading navy [icon] + [label] (Poppins Medium ~16 navy) + a trailing
/// chevron. With [divider] true a hairline divider is drawn beneath the row.
/// Tapping fires [onTap].
class HopListRow extends StatelessWidget {
  /// Creates a list row.
  const HopListRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.divider = false,
    this.trailing,
    super.key,
  });

  /// Leading glyph, painted in the accent (navy) role.
  final IconData icon;

  /// Row label.
  final String label;

  /// Tap intent.
  final VoidCallback onTap;

  /// When true, draws a hairline [Divider] under the row.
  final bool divider;

  /// Optional trailing widget replacing the default chevron (e.g. a switch).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: hoppin.spacing.lg,
              vertical: hoppin.spacing.md,
            ),
            child: Row(
              children: [
                Icon(icon, color: colors.accent, size: 22),
                SizedBox(width: hoppin.spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: hoppin.type.bodyMedium.copyWith(
                      color: colors.textHi,
                    ),
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right,
                      color: colors.textMid,
                      size: 22,
                    ),
              ],
            ),
          ),
        ),
        if (divider)
          Divider(
            height: 1,
            thickness: 1,
            color: colors.hairline,
            indent: hoppin.spacing.lg,
            endIndent: hoppin.spacing.lg,
          ),
      ],
    );
  }
}
