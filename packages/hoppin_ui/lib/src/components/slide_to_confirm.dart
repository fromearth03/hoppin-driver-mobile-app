import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// A horizontal-drag recognizer that claims the gesture arena as soon as it is
/// touched, instead of waiting to out-compete other recognizers.
///
/// The slider lives on a card stacked over a full-bleed map. Both want
/// horizontal drags; the default arena resolution let the map win alongside the
/// thumb, so confirming a trip transition also panned the map. Resolving to
/// `accepted` on the first touch makes the thumb the sole claimant.
class _EagerHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Drag-to-confirm slider for money-affecting trip transitions
/// (driver-ux-motion §5 'Slide-to-advance'; Uber's Sliding button). Start
/// trip and Complete are gesture-gated so a phone bouncing in a cradle
/// cannot fat-finger them — and the gesture itself feels like commitment.
///
/// Behaviour contract:
/// - The thumb tracks the drag 1:1; the label fades via colour alpha as the
///   thumb travels (never an Opacity widget).
/// - Release below ~70% of usable travel springs the thumb home over
///   [HoppinMotion.springBack] (~250ms, elastic-out character).
/// - Release at/past 70% fires [onConfirmed] EXACTLY once, then the thumb
///   accelerates to the end over [HoppinMotion.slideSnap] (~150ms ease-in)
///   and the track fills. The component holds the filled end state — it
///   never self-resets; give it a new [Key] to reset.
/// - [enabled] false ignores all gestures and renders at 60% emphasis.
///
/// Works with mouse drags on web by construction (standard horizontal drag
/// gesture). Pure presentation: one callback out, nothing else.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    required this.label,
    required this.onConfirmed,
    this.enabled = true,
    this.fillColor,
    super.key,
  });

  /// Instruction label centered on the track (e.g. 'Slide to start').
  final String label;

  /// Fired exactly once when the thumb is released past the threshold.
  final VoidCallback onConfirmed;

  /// False renders at 60% emphasis and ignores gestures.
  final bool enabled;

  /// Track fill behind the thumb; defaults to the lane accent.
  final Color? fillColor;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  /// Progress 0..1 of usable travel — the controller's value IS the
  /// progress; drags write it directly, releases animate it.
  late final AnimationController _progress;
  bool _confirmed = false;

  static const double _height = 56;
  static const double _thumbSize = 48;
  static const double _inset = 4;
  static const double _threshold = 0.7;
  static const double _disabledEmphasis = 0.6;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double travel) {
    if (travel <= 0) {
      return;
    }
    _progress.stop();
    _progress.value =
        (_progress.value + details.primaryDelta! / travel).clamp(0.0, 1.0);
  }

  void _onDragEnd() {
    if (_confirmed) {
      return;
    }
    final motion = context.hoppin.motion;
    if (_progress.value >= _threshold) {
      _confirmed = true;
      widget.onConfirmed();
      // §5: past threshold the thumb accelerates to the end (~150ms
      // ease-in) and the track fills; then the slider holds.
      _progress.animateTo(1, duration: motion.slideSnap, curve: Curves.easeIn);
      setState(() {}); // drop the gesture handlers — single fire, forever
    } else {
      // §5: below ~70% travel the release springs home (~250ms).
      _progress.animateTo(
        0,
        duration: motion.springBack,
        curve: Curves.elasticOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final emphasis = widget.enabled ? 1.0 : _disabledEmphasis;
    final active = widget.enabled && !_confirmed;
    final fill = (widget.fillColor ?? colors.accent);
    final radius = BorderRadius.circular(hoppin.radii.card);

    return Semantics(
      label: widget.label,
      enabled: active,
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final travel =
                math.max(0.0, trackWidth - _thumbSize - 2 * _inset);

            return DecoratedBox(
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: emphasis),
                borderRadius: radius,
                border: Border.all(
                  color: colors.hairline.withValues(alpha: emphasis),
                ),
              ),
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  final v = _progress.value.clamp(0.0, 1.0);
                  // Fill always covers the thumb's swept area.
                  final fillFraction = trackWidth <= 0
                      ? 0.0
                      : ((2 * _inset + _thumbSize + v * travel) / trackWidth)
                            .clamp(0.0, 1.0);
                  // Label fades out by ~60% travel — colour alpha only.
                  final labelAlpha = (1 - v / 0.6).clamp(0.0, 1.0);

                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fillFraction,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: fill.withValues(
                              alpha: (0.25 + 0.75 * v) * emphasis,
                            ),
                            borderRadius: radius,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          widget.label,
                          style: hoppin.type.label.copyWith(
                            color: colors.textMid.withValues(
                              alpha: labelAlpha * emphasis,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: _inset),
                        child: Transform.translate(
                          offset: Offset(v * travel, 0),
                          // 🔴 RawGestureDetector, not GestureDetector. A plain
                          // horizontal-drag detector enters the gesture ARENA and
                          // has to win it — but this slider sits on a card over a
                          // full-bleed MapLibre canvas that also claims horizontal
                          // drags, so both were accepted: sliding to confirm
                          // arrival or completion panned the map underneath at the
                          // same time. This recognizer resolves the arena to
                          // itself the instant the thumb is touched, so the drag
                          // never reaches the map.
                          child: RawGestureDetector(
                            behavior: HitTestBehavior.opaque,
                            gestures: active
                                ? <Type, GestureRecognizerFactory>{
                                    _EagerHorizontalDragRecognizer:
                                        GestureRecognizerFactoryWithHandlers<
                                            _EagerHorizontalDragRecognizer>(
                                      _EagerHorizontalDragRecognizer.new,
                                      (r) => r
                                        ..onUpdate =
                                            ((d) => _onDragUpdate(d, travel))
                                        ..onEnd = ((_) => _onDragEnd())
                                        ..onCancel = _onDragEnd,
                                    ),
                                  }
                                : const <Type, GestureRecognizerFactory>{},
                            child: SizedBox(
                              width: _thumbSize,
                              height: _thumbSize,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: fill.withValues(alpha: emphasis),
                                ),
                                child: Icon(
                                  Icons.chevron_right,
                                  size: 28,
                                  color: colors.onAccent.withValues(
                                    alpha: emphasis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
