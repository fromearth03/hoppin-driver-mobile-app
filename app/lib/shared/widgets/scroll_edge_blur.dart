import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// A frosted strip along the bottom of a scrollable screen: while more
/// content waits below the fold, the last rows soften into a blur — the
/// same "there's more" cue the floating pill already hints at. Reaching
/// the very end dissolves it, so the final row is always read in the clear.
///
/// Listens to whatever vertical scrollable lives beneath it; horizontal
/// strips (filter chips, period rows) are ignored. Screens that happen to
/// fit on one screen never show it at all.
class ScrollEdgeBlur extends StatefulWidget {
  final Widget child;

  const ScrollEdgeBlur({super.key, required this.child});

  @override
  State<ScrollEdgeBlur> createState() => _ScrollEdgeBlurState();
}

class _ScrollEdgeBlurState extends State<ScrollEdgeBlur> {
  bool _moreBelow = false;

  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    final more = metrics.hasContentDimensions && metrics.extentAfter > 8;
    if (more != _moreBelow && mounted) setState(() => _moreBelow = more);
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 96,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _moreBelow ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: ClipRect(
                      child: BackdropFilter(
                        // The blur itself fades in via the opacity above;
                        // the gradient keeps its lower edge grounded in the
                        // page colour so the strip has no hard top line.
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.background.withValues(alpha: 0),
                                AppColors.background.withValues(alpha: 0.55),
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
