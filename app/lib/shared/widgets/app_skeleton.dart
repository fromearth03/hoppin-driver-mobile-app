import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// A shimmering placeholder block — the shape of content that has not
/// arrived yet.
///
/// 🔴 A SPINNER THROWS THE SCREEN AWAY; A SKELETON KEEPS IT. Every list in
/// this app used to blank to a centred [AppLoading] on every load and every
/// tab change, so the driver's screen flashed empty and then re-filled — on a
/// phone, in a car, on a connection that is often slow. A skeleton holds the
/// layout still: the rows are already where they will be, and they fill in.
///
/// It is deliberately plain: a rounded box that breathes between two greys.
/// No package, no gradient sweep, nothing that costs a frame budget the trip
/// screen needs for the map.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
  });

  /// Null stretches to the parent — the common case for a text line.
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the OS switch. A driver who has asked the system to stop
    // animating gets a still block, not a pulsing one.
    final animate = !MediaQuery.disableAnimationsOf(context);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: SizedBox(width: widget.width, height: widget.height),
    );

    if (!animate) return box;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.9).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: box,
    );
  }
}

/// A card-shaped placeholder: the outline of a list row, with a title line
/// and a shorter subtitle beneath it.
///
/// Used wherever a screen renders a list of cards — trips, statements,
/// tickets, documents — so a cold open shows the shape of the answer rather
/// than a hole where it will be.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 2, this.trailing = true});

  /// How many text lines the real row carries.
  final int lines;

  /// Whether the real row has something right-aligned (an amount, a chevron).
  final bool trailing;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lines; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    // Later lines are shorter, the way real secondary text is.
                    Skeleton(width: i == 0 ? 180 : 120, height: i == 0 ? 16 : 12),
                  ],
                ],
              ),
            ),
            if (trailing) ...[
              const SizedBox(width: 12),
              const Skeleton(width: 56, height: 16),
            ],
          ],
        ),
      );
}

/// A list of [SkeletonCard]s — the standard placeholder for any screen whose
/// content is "some rows".
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 4,
    this.lines = 2,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
  });

  final int count;
  final int lines;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListView(
        // Always scrollable so a pull-to-refresh still works over the
        // placeholder — a driver who opens on a slow connection can retry
        // without waiting for the first paint to finish.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          for (var i = 0; i < count; i++) SkeletonCard(lines: lines),
        ],
      );
}
