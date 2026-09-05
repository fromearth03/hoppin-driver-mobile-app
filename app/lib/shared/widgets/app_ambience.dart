import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// The ground the app's glass refracts.
///
/// 🔴 A BLUR OF A FLAT THING LOOKS LIKE THE FLAT THING. This is why the first
/// attempt at glass here read as "just layers": a `BackdropFilter` samples
/// what is painted behind it, and behind every card was one smooth gradient.
/// Blurring a smooth gradient returns very nearly the same smooth gradient, so
/// the surface had nothing to show for the filter it was paying for.
///
/// The nav pill and the presence pill look like glass for a reason the cards
/// did not share: **content scrolls underneath them**. Hard edges — a photo,
/// a number, a row of text — smear as they pass, and that smear is the whole
/// effect.
///
/// So the ground is no longer smooth. It carries high-contrast structure at a
/// scale the blur can actually chew on: saturated colour pools with hard
/// falloff, and a fine diagonal grille whose lines are thin enough to dissolve
/// into a sheen under an 18px blur but wide enough to modulate it. Combined
/// with cards that let real content pass beneath them, the material finally
/// has something to bend.
class AppAmbience extends StatelessWidget {
  const AppAmbience({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A driver who asked the OS to cut transparency gets the flat ground: the
    // structure below exists to be refracted, and nothing above it will be
    // blurring.
    if (MediaQuery.highContrastOf(context)) {
      return ColoredBox(color: AppColors.background, child: child);
    }

    return Stack(
      children: [
        const Positioned.fill(child: _Ground()),
        child,
      ],
    );
  }
}

class _Ground extends StatelessWidget {
  const _Ground();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8E2F6), // indigo cast
              Color(0xFFF1EFF3),
              Color(0xFFFBEFE4), // warm cast
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Colour pools. Deliberately strong: what survives an 18px blur
            // and a 1.6× saturation is a fraction of what goes in, and a wash
            // faint enough to look tasteful bare is invisible once filtered.
            Positioned(
              top: -140,
              left: -90,
              child: _Pool(
                color: AppColors.primary.withValues(alpha: 0.30),
                size: 360,
              ),
            ),
            Positioned(
              top: 220,
              right: -170,
              child: _Pool(
                color: AppColors.primaryLight.withValues(alpha: 0.26),
                size: 340,
              ),
            ),
            Positioned(
              bottom: 120,
              left: -120,
              child: _Pool(
                color: AppColors.info.withValues(alpha: 0.20),
                size: 300,
              ),
            ),
            Positioned(
              bottom: -160,
              right: -110,
              child: _Pool(
                color: AppColors.accent.withValues(alpha: 0.28),
                size: 400,
              ),
            ),
            // The grille. Thin diagonal lines at very low alpha: invisible as
            // lines, but they give the blur a high-frequency signal to smear
            // into the soft sheen that reads as thickness in the glass above.
            const Positioned.fill(
              child: IgnorePointer(child: _Grille()),
            ),
          ],
        ),
      );
}

/// One soft radial bloom. A radial gradient fading to transparent costs
/// nothing next to a second blur pass and reads the same at this softness.
class _Pool extends StatelessWidget {
  const _Pool({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      );
}

class _Grille extends StatelessWidget {
  const _Grille();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GrillePainter(), size: Size.infinite);
}

class _GrillePainter extends CustomPainter {
  static const _spacing = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Diagonals rather than verticals: a vertical grille aligns with the edges
    // of every card and reads as banding, while a diagonal one never lines up
    // with anything and dissolves into texture.
    for (var x = -size.height; x < size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrillePainter oldDelegate) => false;
}
