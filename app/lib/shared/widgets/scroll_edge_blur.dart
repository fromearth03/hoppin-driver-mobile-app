import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// A frosted strip along the bottom of a scrollable screen: while more
/// content waits below the fold, the last rows soften — the same "there's
/// more" cue the floating pill already hints at. Reaching the very end
/// dissolves it, so the final row is always read in the clear.
///
/// The strength tracks how much is left below rather than switching on a
/// threshold. An on/off strip announced itself in one frame — full blur, then
/// nothing — which read as a glitch on exactly the screens where the driver
/// is scrolling fastest. Tying it to [_fadeDistance] of remaining content
/// means it thickens as they scroll into a long page and thins away as the
/// end arrives, so it is never seen to appear.
///
/// Listens to whatever vertical scrollable lives beneath it; horizontal
/// strips (filter chips, period rows) are ignored. Screens that happen to fit
/// on one screen never show it at all.
class ScrollEdgeBlur extends StatefulWidget {
  final Widget child;

  const ScrollEdgeBlur({super.key, required this.child});

  /// The strip itself, so tests can read its strength.
  static const stripKey = ValueKey('scroll-edge-blur-strip');

  @override
  State<ScrollEdgeBlur> createState() => _ScrollEdgeBlurState();
}

class _ScrollEdgeBlurState extends State<ScrollEdgeBlur> {
  /// 0 at the end of the list, 1 while a full screenful still waits below.
  double _strength = 0;

  /// How much remaining content counts as "plenty more". Roughly the height
  /// of the strip itself, so the cue has faded out by the time the last rows
  /// are on screen and never covers the final one.
  static const _fadeDistance = 120.0;

  /// The deepest the blur goes. Deliberately gentle: this is a hint that the
  /// page continues, not a scrim, and the rows under it stay readable.
  static const _maxSigma = 3.5;

  static const _height = 96.0;

  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    if (!metrics.hasContentDimensions) return false;
    final next = (metrics.extentAfter / _fadeDistance).clamp(0.0, 1.0);
    // Repainting on sub-pixel deltas would rebuild the backdrop filter on
    // every frame of an inertial fling for no visible gain.
    if ((next - _strength).abs() > 0.01 && mounted) {
      setState(() => _strength = next);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _onMetrics(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _onMetrics(n.metrics),
          child: Stack(
            children: [
              widget.child,
              // Nothing below the fold: no strip in the tree at all, so a
              // short page pays nothing for a widget it never shows.
              if (_strength > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _height,
                  child: IgnorePointer(
                    child: Opacity(
                      key: ScrollEdgeBlur.stripKey,
                      opacity: _strength,
                      child: ClipRect(
                        child: BackdropFilter(
                          // The sigma rides the same curve as the opacity, so
                          // the blur grows and recedes with the scroll rather
                          // than snapping to full depth the moment it shows.
                          filter: ImageFilter.blur(
                            sigmaX: _maxSigma * _strength,
                            sigmaY: _maxSigma * _strength,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.background.withValues(alpha: 0),
                                  AppColors.background.withValues(alpha: 0.42),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
