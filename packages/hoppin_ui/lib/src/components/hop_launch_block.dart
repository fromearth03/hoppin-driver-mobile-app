import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import 'hop_button.dart';

/// A full-screen, NON-DISMISSIBLE launch block — maintenance or force-update.
///
/// This is the hard gate: it replaces the entire app, has no back affordance and
/// no way past it, because both states it serves mean the app genuinely cannot
/// be used (down for maintenance) or must not be used (a build below the
/// required floor). The soft "update available" nudge is NOT this — that is a
/// dismissible banner, handled separately.
///
/// Pure presentation: it owns no data and no navigation. The launch layer
/// decides which block to show and wires [onAction].
class HopLaunchBlock extends StatelessWidget {
  const HopLaunchBlock({
    required this.icon,
    required this.headline,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Maintenance uses a construction/clock glyph; force-update an upgrade one.
  final IconData icon;
  final String headline;
  final String body;

  /// The one action, if any. Maintenance has none (nothing the user can do);
  /// force-update offers "Update now" → the store.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    // Its own Material + theme host: the block renders in the app-launch
    // `builder`, which may sit ABOVE the Navigator, so it cannot assume an
    // ancestor Scaffold.
    return Material(
      color: colors.canvas,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(hoppin.spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.accentSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: colors.accent),
                ),
                SizedBox(height: hoppin.spacing.lg),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: hoppin.type.section.copyWith(color: colors.textHi),
                ),
                SizedBox(height: hoppin.spacing.md),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: hoppin.type.body.copyWith(color: colors.textMid),
                ),
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: hoppin.spacing.xl),
                  HopButton.primary(label: actionLabel!, onPressed: onAction),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
