import 'package:flutter/material.dart';

/// Motion tokens for the Hoppin motion language (driver-ux-motion spec §5).
///
/// Every animation in hoppin_ui and on the demo path takes its duration from
/// these tokens — no inline [Duration] literals in animation code (05-03
/// enforces this with a sweep).
class HoppinMotion extends ThemeExtension<HoppinMotion> {
  const HoppinMotion({
    required this.easeSignature,
    required this.easeOut,
    required this.fade,
    required this.quick,
    required this.slow,
    required this.offerEntrance,
    required this.radarPeriod,
    required this.radarStagger,
    required this.goPulsePeriod,
    required this.countdownTotal,
    required this.morphOut,
    required this.morphIn,
    required this.morphOverlap,
    required this.dotPop,
    required this.springBack,
    required this.slideSnap,
    required this.tickerCountUp,
    required this.checkPop,
    required this.tileAbsorbTick,
    required this.tileAbsorbDelay,
    required this.chipRise,
    required this.tintPulse,
    required this.countdownBreatheWindow,
    required this.secondsTick,
    required this.mapCamera,
    required this.mapCameraDebounce,
  });

  /// The one signature ease — quintic character, cubic-bezier(.86,0,.07,1).
  final Curve easeSignature;

  /// Utility ease-out for arrivals and tickers.
  final Curve easeOut;

  /// 100ms — opacity-style fades.
  final Duration fade;

  /// 250ms — standard state changes.
  final Duration quick;

  /// 500ms — large choreographed moves.
  final Duration slow;

  /// Offer takeover card slide-up.
  final Duration offerEntrance;

  /// One radar ring expansion period.
  final Duration radarPeriod;

  /// Delay between staggered radar rings.
  final Duration radarStagger;

  /// GO button breathing pulse period.
  final Duration goPulsePeriod;

  /// Full offer countdown window.
  final Duration countdownTotal;

  /// Card morph: outgoing content exit.
  final Duration morphOut;

  /// Card morph: incoming content entrance.
  final Duration morphIn;

  /// Card morph: how long the outgoing tail and incoming head overlap —
  /// the incoming content starts morphOut − morphOverlap after the switch.
  final Duration morphOverlap;

  /// Stage-progress dot pop.
  final Duration dotPop;

  /// Slide-to-confirm thumb release return.
  final Duration springBack;

  /// Slide-to-confirm completion snap.
  final Duration slideSnap;

  /// Earned-money odometer count-up.
  final Duration tickerCountUp;

  /// Success check pop.
  final Duration checkPop;

  /// Dashboard tile total ticking up during absorb.
  final Duration tileAbsorbTick;

  /// Pause before the dashboard absorb starts.
  final Duration tileAbsorbDelay;

  /// "+£x.xx" chip rise-and-fade.
  final Duration chipRise;

  /// Accent tint pulse on updated tiles.
  final Duration tintPulse;

  /// The countdown ring's final window in which its inner content breathes.
  final Duration countdownBreatheWindow;

  /// Cadence of 1Hz numeric readouts (countdown seconds) — kept OUTSIDE
  /// per-frame repaints by contract.
  final Duration secondsTick;

  /// HopMap camera glide — every eased `animateTo`/fit runs this long.
  final Duration mapCamera;

  /// HopMap follow-camera re-aim window: the chase camera skips a re-aim
  /// unless the target drifted far enough or this much time elapsed — the
  /// marker tween carries intra-sample smoothness, the camera glides.
  final Duration mapCameraDebounce;

  /// Default HopMap position sample cadence (1 Hz — the demo tick and the
  /// live poll interval). DATA cadence rather than motion; it lives here so
  /// HopMap's default-parameter fallback stays literal-free under the 05-03
  /// components sweep.
  static const Duration mapSampleInterval = Duration(seconds: 1);

  /// The Hoppin motion language: one signature ease, 100/250/500 scale, and
  /// the named choreography durations from the motion spec.
  static const HoppinMotion standard = HoppinMotion(
    easeSignature: Cubic(0.86, 0, 0.07, 1),
    easeOut: Curves.easeOutCubic,
    fade: Duration(milliseconds: 100),
    quick: Duration(milliseconds: 250),
    slow: Duration(milliseconds: 500),
    offerEntrance: Duration(milliseconds: 350),
    radarPeriod: Duration(milliseconds: 2000),
    radarStagger: Duration(milliseconds: 600),
    goPulsePeriod: Duration(milliseconds: 1400),
    countdownTotal: Duration(seconds: 15),
    morphOut: Duration(milliseconds: 120),
    morphIn: Duration(milliseconds: 200),
    morphOverlap: Duration(milliseconds: 40),
    dotPop: Duration(milliseconds: 300),
    springBack: Duration(milliseconds: 250),
    slideSnap: Duration(milliseconds: 150),
    tickerCountUp: Duration(milliseconds: 900),
    checkPop: Duration(milliseconds: 400),
    tileAbsorbTick: Duration(milliseconds: 700),
    tileAbsorbDelay: Duration(milliseconds: 300),
    chipRise: Duration(milliseconds: 600),
    tintPulse: Duration(milliseconds: 400),
    countdownBreatheWindow: Duration(seconds: 3),
    secondsTick: Duration(seconds: 1),
    mapCamera: Duration(milliseconds: 800),
    mapCameraDebounce: Duration(seconds: 2),
  );

  static Duration _lerpDur(Duration a, Duration b, double t) => Duration(
    microseconds: (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t)
        .round(),
  );

  @override
  HoppinMotion copyWith({
    Curve? easeSignature,
    Curve? easeOut,
    Duration? fade,
    Duration? quick,
    Duration? slow,
    Duration? offerEntrance,
    Duration? radarPeriod,
    Duration? radarStagger,
    Duration? goPulsePeriod,
    Duration? countdownTotal,
    Duration? morphOut,
    Duration? morphIn,
    Duration? morphOverlap,
    Duration? dotPop,
    Duration? springBack,
    Duration? slideSnap,
    Duration? tickerCountUp,
    Duration? checkPop,
    Duration? tileAbsorbTick,
    Duration? tileAbsorbDelay,
    Duration? chipRise,
    Duration? tintPulse,
    Duration? countdownBreatheWindow,
    Duration? secondsTick,
    Duration? mapCamera,
    Duration? mapCameraDebounce,
  }) {
    return HoppinMotion(
      easeSignature: easeSignature ?? this.easeSignature,
      easeOut: easeOut ?? this.easeOut,
      fade: fade ?? this.fade,
      quick: quick ?? this.quick,
      slow: slow ?? this.slow,
      offerEntrance: offerEntrance ?? this.offerEntrance,
      radarPeriod: radarPeriod ?? this.radarPeriod,
      radarStagger: radarStagger ?? this.radarStagger,
      goPulsePeriod: goPulsePeriod ?? this.goPulsePeriod,
      countdownTotal: countdownTotal ?? this.countdownTotal,
      morphOut: morphOut ?? this.morphOut,
      morphIn: morphIn ?? this.morphIn,
      morphOverlap: morphOverlap ?? this.morphOverlap,
      dotPop: dotPop ?? this.dotPop,
      springBack: springBack ?? this.springBack,
      slideSnap: slideSnap ?? this.slideSnap,
      tickerCountUp: tickerCountUp ?? this.tickerCountUp,
      checkPop: checkPop ?? this.checkPop,
      tileAbsorbTick: tileAbsorbTick ?? this.tileAbsorbTick,
      tileAbsorbDelay: tileAbsorbDelay ?? this.tileAbsorbDelay,
      chipRise: chipRise ?? this.chipRise,
      tintPulse: tintPulse ?? this.tintPulse,
      countdownBreatheWindow:
          countdownBreatheWindow ?? this.countdownBreatheWindow,
      secondsTick: secondsTick ?? this.secondsTick,
      mapCamera: mapCamera ?? this.mapCamera,
      mapCameraDebounce: mapCameraDebounce ?? this.mapCameraDebounce,
    );
  }

  @override
  HoppinMotion lerp(ThemeExtension<HoppinMotion>? other, double t) {
    if (other is! HoppinMotion) {
      return this;
    }
    // Curves cannot meaningfully interpolate — snap at the halfway point.
    final curves = t < 0.5 ? this : other;
    return HoppinMotion(
      easeSignature: curves.easeSignature,
      easeOut: curves.easeOut,
      fade: _lerpDur(fade, other.fade, t),
      quick: _lerpDur(quick, other.quick, t),
      slow: _lerpDur(slow, other.slow, t),
      offerEntrance: _lerpDur(offerEntrance, other.offerEntrance, t),
      radarPeriod: _lerpDur(radarPeriod, other.radarPeriod, t),
      radarStagger: _lerpDur(radarStagger, other.radarStagger, t),
      goPulsePeriod: _lerpDur(goPulsePeriod, other.goPulsePeriod, t),
      countdownTotal: _lerpDur(countdownTotal, other.countdownTotal, t),
      morphOut: _lerpDur(morphOut, other.morphOut, t),
      morphIn: _lerpDur(morphIn, other.morphIn, t),
      morphOverlap: _lerpDur(morphOverlap, other.morphOverlap, t),
      dotPop: _lerpDur(dotPop, other.dotPop, t),
      springBack: _lerpDur(springBack, other.springBack, t),
      slideSnap: _lerpDur(slideSnap, other.slideSnap, t),
      tickerCountUp: _lerpDur(tickerCountUp, other.tickerCountUp, t),
      checkPop: _lerpDur(checkPop, other.checkPop, t),
      tileAbsorbTick: _lerpDur(tileAbsorbTick, other.tileAbsorbTick, t),
      tileAbsorbDelay: _lerpDur(tileAbsorbDelay, other.tileAbsorbDelay, t),
      chipRise: _lerpDur(chipRise, other.chipRise, t),
      tintPulse: _lerpDur(tintPulse, other.tintPulse, t),
      countdownBreatheWindow: _lerpDur(
        countdownBreatheWindow,
        other.countdownBreatheWindow,
        t,
      ),
      secondsTick: _lerpDur(secondsTick, other.secondsTick, t),
      mapCamera: _lerpDur(mapCamera, other.mapCamera, t),
      mapCameraDebounce: _lerpDur(
        mapCameraDebounce,
        other.mapCameraDebounce,
        t,
      ),
    );
  }
}
