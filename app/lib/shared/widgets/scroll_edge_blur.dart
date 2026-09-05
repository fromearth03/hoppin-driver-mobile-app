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
  static const _fadeDistance = 420.0;

  /// The deepest the blur goes. Deliberately gentle: this is a hint that the
  /// page continues, not a scrim, and the rows under it stay readable.
  static const _maxSigma = 6.0;

  static const _height = 230.0;

  /// How many graded bands make up the ramp. Enough that the steps are below
  /// the eye's threshold at this height; few enough that the frame cost stays
  /// reasonable on a mid-range handset.
  static const _bands = 12;

  /// Cubic rather than quadratic: the ramp starts flatter, so the top of the
  /// strip is imperceptibly soft and the depth only gathers near the foot.
  /// A quadratic still began too abruptly to read as continuous.
  static double _curve(double t) => t * t * t;

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
                      // 🔴 A SINGLE BackdropFilter HAS A HARD TOP EDGE. One
                      // filter blurs its whole rectangle uniformly, so the
                      // boundary between blurred and unblurred content is a
                      // visible seam sliding up the page as you scroll.
                      //
                      // Stacking bands, each blurring a little more than the
                      // one above and each masked to fade in, ramps the blur
                      // instead of switching it on. The eye reads a gradient;
                      // there is no line to catch.
                      child: Column(
                        children: [
                          for (var i = 0; i < _bands; i++)
                            Expanded(
                              child: _BlurBand(
                                // Quadratic so the top band is nearly clear
                                // and the depth gathers toward the bottom
                                // edge, the way a real depth-of-field falls
                                // off rather than stepping.
                                sigma: _maxSigma *
                                    _strength *
                                    _curve((i + 1) / _bands),
                                veil: 0.30 * _curve((i + 1) / _bands),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// One horizontal slice of the ramp: a blur plus a matching veil.
///
/// Separated so each band clips its own filter — a BackdropFilter samples what
/// is painted behind it, so bands must not nest or the lower ones would blur
/// an already-blurred layer and the ramp would compound instead of grade.
class _BlurBand extends StatelessWidget {
  const _BlurBand({required this.sigma, required this.veil});

  final double sigma;
  final double veil;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: veil),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
}
