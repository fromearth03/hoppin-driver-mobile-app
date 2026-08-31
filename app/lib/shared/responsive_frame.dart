import 'package:flutter/material.dart';

import '../core/theme/colors.dart';

/// Keeps the app phone-shaped on any screen.
///
/// The Figma is a phone design; every screen is composed for a ~430pt
/// column. On a phone this frame is invisible — the child fills the window
/// untouched. Past [breakpoint] the app renders as a centred phone-width
/// column on a brand backdrop, the way mobile-first products present on
/// tablets and desktops, instead of stretching rows across a Surface Pro.
///
/// This wraps the router's navigator, so dialogs, bottom sheets and snack
/// bars are constrained with it — nothing escapes the column.
class ResponsiveFrame extends StatelessWidget {
  final Widget child;

  /// Above this width the column engages. Wider than any phone in portrait,
  /// narrower than any tablet: an iPhone 16 Pro Max is 430, a small Android
  /// tablet 600.
  static const breakpoint = 520.0;

  /// The column's width on large screens: the Figma artboard's own width,
  /// so large-screen rendering is exactly the layout every screen was
  /// designed and tested at.
  static const columnWidth = 430.0;

  const ResponsiveFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= breakpoint) return child;

    // Tall screens get a margin above and below the column so it reads as a
    // device; short-and-wide ones (a landscape laptop) give the column the
    // full height rather than squeezing the app into a letterbox.
    final vertical = size.height > 900 ? 24.0 : 0.0;
    final radius = vertical > 0 ? 28.0 : 0.0;

    return ColoredBox(
      color: AppColors.primaryDark,
      child: Stack(
        children: [
          // A quiet wash of the brand gradient, not a poster: the backdrop
          // must never compete with the app in front of it.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryLight, AppColors.primaryDark],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: vertical),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: columnWidth,
                  height: size.height - vertical * 2,
                  // The app must believe the window IS the column: screens
                  // read MediaQuery for sizing (BrandHeader takes a height
                  // fraction of it), and without this override they would
                  // size against the full desktop window behind the frame.
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(columnWidth, size.height - vertical * 2),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
