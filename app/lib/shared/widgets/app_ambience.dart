import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// The ground the app's glass refracts.
///
/// 🔴 GLASS OVER A FLAT COLOUR IS NOT GLASS. A `BackdropFilter` blurs whatever
/// is painted behind it, so a frosted card over a single flat grey blurs grey
/// into grey and reads as a plain translucent box. The material only becomes
/// legible as glass when there is something varied behind it to bend.
///
/// This lays that something down once, behind the whole app: a pale wash with
/// two soft colour pools drifting through it, drawn from the brand's own
/// indigo and orange. It is deliberately faint — this is the ground a driver
/// reads white text and dark figures against all shift, so it stays close to
/// the old flat background in value and only varies in hue.
///
/// Painted once at the shell, not per screen: every card, sheet and pill above
/// it then has a real backdrop, and the cost is one gradient rather than one
/// per surface.
class AppAmbience extends StatelessWidget {
  const AppAmbience({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A driver who asked the OS to cut transparency gets the flat ground: the
    // pools exist to be refracted, and nothing above them will be blurring.
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
          // The base wash: a touch cooler at the top, warmer at the foot, so a
          // long scroll never sits on one dead value.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3F1F8), // faint indigo cast
              Color(0xFFEFEFEF), // the app's established ground
              Color(0xFFF7F2EE), // faint warm cast
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Two pools of brand colour at very low alpha. These are what a
            // blurred surface actually picks up and smears — without them the
            // glass has nothing to say.
            Positioned(
              top: -120,
              left: -80,
              child: _Pool(
                color: AppColors.primary.withValues(alpha: 0.10),
                size: 340,
              ),
            ),
            Positioned(
              bottom: -140,
              right: -100,
              child: _Pool(
                color: AppColors.accent.withValues(alpha: 0.09),
                size: 380,
              ),
            ),
          ],
        ),
      );
}

/// One soft radial bloom. A plain circle with a blur would cost a second
/// filter pass; a radial gradient fading to transparent is free and reads the
/// same at this softness.
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
              ),
            ),
          ),
        ),
      );
}
