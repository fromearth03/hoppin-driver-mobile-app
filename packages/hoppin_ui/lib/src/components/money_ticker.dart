import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import '../theme/hoppin_typography.dart';

/// Pence-based animated money value — the earnings odometer beat
/// (driver-ux-motion §5 'Number ticker'). Used by the dashboard earnings
/// tile, the earned moment, and rider fares/receipts.
///
/// BEHAVIOURAL CONTRACT (consuming riblets code against every clause):
///
/// - Renders `'£x.xx'` from an integer [pence] value. Formatting is
///   duplicated from hoppin_shared's money convention ON PURPOSE —
///   hoppin_ui must not depend on hoppin_shared.
/// - **First build renders statically** at [pence] — no count-up on mount —
///   UNLESS [fromPence] is provided and differs, in which case the ticker
///   mounts showing [fromPence] and immediately animates to [pence]. That
///   seeding rule exists for consumers that remount mid-choreography (the
///   dashboard absorb beat) and still need the tick-up to render visibly.
/// - When [pence] changes on an existing element, the displayed value
///   animates old → new over [duration] ?? [HoppinMotion.tickerCountUp]
///   (900ms) with the ease-out token ([Curves.easeOutCubic] character);
///   retargeting mid-flight restarts from the currently displayed value,
///   never snapping.
/// - [delay] holds the start value on screen before the roll begins — the
///   §5 absorb rule ([HoppinMotion.tileAbsorbDelay]): the driver must land
///   first, then witness the tick-up. The hold rides the same controller
///   (an Interval), so tests drive it with bounded pumps, no wall timers.
/// - **The roll is an odometer** (§5): while animating, each digit renders
///   as a vertical strip of static [Text] glyphs inside a [ClipRect],
///   translated by the digit's fractional value — increases roll UP. The
///   `£` sign and decimal point never move. At rest the whole value renders
///   as ONE static [Text] (cheap, and `find.text('£x.xx')` keeps working).
/// - Digits use tabular figures ([HoppinType.moneyTitle] GeistMono default
///   in textHi), so cell widths never jitter. A caller [style] merges over
///   the default; the tabular default survives unless explicitly
///   overridden.
///
/// Pure presentation: the value arrives via constructor; no repositories,
/// no clocks, no riverpod.
class MoneyTicker extends StatefulWidget {
  const MoneyTicker({
    required this.pence,
    this.fromPence,
    this.duration,
    this.delay,
    this.style,
    super.key,
  });

  /// The value to display (and animate towards), in pence.
  final int pence;

  /// Optional mount seed: when non-null and different from [pence], the
  /// first frame renders [fromPence] and the ticker animates to [pence]
  /// from there. Null (default) keeps the static first build.
  final int? fromPence;

  /// Count-up duration; defaults to [HoppinMotion.tickerCountUp] (900ms).
  final Duration? duration;

  /// Optional hold before the roll starts (the start value stays on
  /// screen); null means the roll begins immediately.
  final Duration? delay;

  /// Merged over the tabular GeistMono default.
  final TextStyle? style;

  @override
  State<MoneyTicker> createState() => _MoneyTickerState();
}

class _MoneyTickerState extends State<MoneyTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  CurvedAnimation? _curve;
  late double _from;
  late int _to;
  bool _mountKicked = false;

  @override
  void initState() {
    super.initState();
    _to = widget.pence;
    _from = (widget.fromPence ?? widget.pence).toDouble();
    _controller = AnimationController(vsync: this, value: 1);
  }

  /// Resolves duration + delay into the controller and its eased curve.
  /// The delay is an [Interval] head on the same controller — no timers.
  void _configure() {
    final run = widget.duration ?? context.hoppin.motion.tickerCountUp;
    final delay = widget.delay ?? Duration.zero;
    final total = delay + run;
    _controller.duration = total;
    _curve?.dispose();
    _curve = CurvedAnimation(
      parent: _controller,
      curve: delay == Duration.zero || total == Duration.zero
          ? Curves.easeOutCubic
          : Interval(
              delay.inMicroseconds / total.inMicroseconds,
              1,
              curve: Curves.easeOutCubic,
            ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
    if (!_mountKicked) {
      _mountKicked = true;
      if (_from != _to) {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void didUpdateWidget(MoneyTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
    if (widget.pence != _to) {
      // Retarget from whatever is on screen right now.
      _from = _displayValue;
      _to = widget.pence;
      _controller.forward(from: 0);
    }
  }

  double get _displayValue {
    final t = _curve?.value ?? 1.0;
    return _from + (_to - _from) * t;
  }

  String _format(double pence) => '£${(pence / 100).toStringAsFixed(2)}';

  @override
  void dispose() {
    _curve?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hoppin.colors;
    // Belt-and-braces tabular figures: digits must never jitter width, even
    // if the base money style ever evolves.
    final defaultStyle = HoppinType.moneyTitle.copyWith(
      color: colors.textHi,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final style = widget.style == null
        ? defaultStyle
        : defaultStyle.merge(widget.style);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _curve?.value ?? 1.0;
        final rolling = _controller.isAnimating &&
            t > 0 &&
            t < 1 &&
            _from != _to &&
            _from >= 0 &&
            _to >= 0;
        if (!rolling) {
          // At rest (and through any delay hold) the value is ONE static
          // Text — no per-frame strips, and finders read the whole string.
          return Text(_format(_displayValue), style: style);
        }
        return _OdometerRow(
          value: _displayValue,
          maxValue: math.max(_from, _to.toDouble()),
          targetLabel: _format(_to.toDouble()),
          style: style,
        );
      },
    );
  }
}

/// The mid-roll odometer: static `£`/`.` glyphs around per-digit strips.
/// Rebuilt per frame under the ticker's AnimatedBuilder — each strip is two
/// static [Text] glyphs in a [ClipRect] moved by [Transform.translate], so
/// the web budget sees transforms only.
class _OdometerRow extends StatelessWidget {
  const _OdometerRow({
    required this.value,
    required this.maxValue,
    required this.targetLabel,
    required this.style,
  });

  /// The continuous display value, in pence.
  final double value;

  /// The larger flight endpoint — fixes the pound-digit count so the row
  /// never changes width mid-roll (tabular figures fix the rest).
  final double maxValue;

  /// The flight target, announced whole to assistive tech mid-roll.
  final String targetLabel;

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // One single-glyph measurement fixes every cell (tabular figures make
    // all digits share the '0' advance).
    final probe = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final cellWidth = probe.width;
    final cellHeight = probe.height;
    probe.dispose();

    final pounds = (maxValue / 100).floor();
    final poundDigits = pounds.toString().length;

    final cells = <Widget>[Text('£', style: style)];
    for (var i = poundDigits - 1; i >= 0; i--) {
      final place = 100 * math.pow(10.0, i).toDouble();
      cells.add(_digitCell(value / place, cellWidth, cellHeight));
    }
    cells
      ..add(Text('.', style: style))
      ..add(_digitCell(value / 10, cellWidth, cellHeight))
      ..add(_digitCell(value, cellWidth, cellHeight));

    return Semantics(
      label: targetLabel,
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: cells),
      ),
    );
  }

  /// One rolling digit: the current glyph slides up out of the clip while
  /// its successor rises from below (increases roll UP; decreases play the
  /// same geometry backwards as the fraction shrinks).
  Widget _digitCell(double raw, double width, double height) {
    final scaled = raw % 10;
    final digit = scaled.floor() % 10;
    final frac = scaled - scaled.floorToDouble();
    final next = (digit + 1) % 10;
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, -frac * height),
              child: Text('$digit', style: style),
            ),
            if (frac > 0)
              Transform.translate(
                offset: Offset(0, (1 - frac) * height),
                child: Text('$next', style: style),
              ),
          ],
        ),
      ),
    );
  }
}
