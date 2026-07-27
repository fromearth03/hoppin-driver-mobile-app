import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import '../tokens/spacing.dart';
import 'hop_glass.dart';

/// One tab in the [HopBottomNav]: its [icon] and [label].
class HopNavItem {
  /// Creates a bottom-nav tab.
  const HopNavItem({required this.icon, required this.label});

  /// The tab glyph — shown alone when inactive, beside the label when active.
  final IconData icon;

  /// The tab label — painted white inside the active navy capsule; hidden
  /// (icon-only) when inactive.
  final String label;
}

/// The rider bottom navigation bar: FROSTED, but ANCHORED.
///
/// It takes the same glass as the floating top pill — the same blur, the same
/// fill, the same rim — and the page scrolls underneath it. It does NOT become
/// a floating pill: it stays welded to the bottom edge, full width and
/// safe-area aware, because that edge is the thumb's home and a nav that has
/// drifted inboard of it is a nav you have to reach for. Only its TOP corners
/// are rounded; the bottom two meet the screen, and rounding a corner against
/// nothing just puts a notch of canvas in the way.
///
/// Exactly four fixed tabs. The active tab is a navy (`colors.accent`) capsule
/// carrying its icon + label in `onAccent`; inactive tabs are icon-only glyphs
/// at `textHi` — pulled up from `textMid`, because mid-emphasis grey that reads
/// fine on an opaque white bar starts to swim once the bar is translucent and a
/// map is sliding past behind it.
///
/// `onTap(index)` reports the tapped index — the shell wires this to `goBranch`.
class HopBottomNav extends StatelessWidget {
  /// Creates the rider bottom nav. Pass [items] to override the default four
  /// tabs (Book/History/Payments/Support).
  const HopBottomNav({
    required this.currentIndex,
    required this.onTap,
    this.items = defaultItems,
    super.key,
  });

  /// The four fixed rider tabs, in shell-branch order.
  static const List<HopNavItem> defaultItems = <HopNavItem>[
    HopNavItem(icon: Icons.explore_outlined, label: 'Book'),
    HopNavItem(icon: Icons.history, label: 'History'),
    HopNavItem(icon: Icons.account_balance_wallet_outlined, label: 'Payments'),
    HopNavItem(icon: Icons.support_agent_outlined, label: 'Support'),
  ];

  /// The active tab index.
  final int currentIndex;

  /// Fired with the tapped tab index (shell → `goBranch`).
  final ValueChanged<int> onTap;

  /// The tabs to render — four fixed tabs by default.
  final List<HopNavItem> items;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return HopGlass(
      // Anchored: only the top corners curve. `floating: false` withholds the
      // drop shadow — a cast needs a gap to fall across, and there is none
      // under a bar that is flush with the screen. Its rim does the separating.
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(hoppin.radii.pillSmall),
      ),
      floating: false,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hoppin.spacing.sm,
            vertical: hoppin.spacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _tab(context, i, items[i], active: i == currentIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    int index,
    HopNavItem item, {
    required bool active,
  }) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    // The active capsule is a TRUE pill, matching the top bar's stadium — the
    // 12pt control radius it used to carry read as a rounded rectangle, which
    // put two different corner languages in the same frame of chrome.
    final radius = BorderRadius.circular(hoppin.radii.pill);

    final child = active
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: radius,
              // The navy capsule is the only OPAQUE thing on the glass, so it
              // is what the eye lands on. It gets its own small cast so it sits
              // proud of the pane rather than being embedded in it.
              boxShadow: HoppinShadows.card,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: hoppin.spacing.lg,
                vertical: hoppin.spacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 22, color: colors.onAccent),
                  SizedBox(width: hoppin.spacing.sm),
                  Text(
                    item.label,
                    style: hoppin.type.bodyMedium.copyWith(
                      color: colors.onAccent,
                    ),
                  ),
                ],
              ),
            ),
          )
        : Padding(
            padding: EdgeInsets.symmetric(
              horizontal: hoppin.spacing.md,
              vertical: hoppin.spacing.md,
            ),
            // textHi, not textMid: a 60%-black glyph is legible on an opaque
            // white bar and starts to disappear the moment that bar goes
            // translucent over a moving map.
            child: Icon(item.icon, size: 24, color: colors.textHi),
          );

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: radius,
        child: child,
      ),
    );
  }
}
