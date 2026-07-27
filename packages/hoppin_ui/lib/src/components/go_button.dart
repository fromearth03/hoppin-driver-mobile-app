import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// The driver dashboard's go-online affordance — a large circular button
/// that breathes while offline and quiets down once online (driver-ux-motion
/// §5 'Go button pulse'; Uber's post-toggle pattern).
///
/// Pure presentation: state in via [online]/[busy], events out via
/// [onPressed]. The consuming riblet decides what going online means.
///
/// Motion contract:
/// - Offline: the circle breathes scale 1.0→1.05 on a reverse-repeat loop
///   ([HoppinMotion.goPulsePeriod], ease-in-out) with a soft echo circle
///   behind it — a second pre-painted circle at low paint alpha scaling
///   slightly ahead on the same controller. No animated shadows, ever.
/// - Press: the whole button dips to scale 0.96 over [HoppinMotion.fade]
///   (§5: ~100ms) and releases; [onPressed] fires exactly once per tap.
/// - Online: the loop stops dead (controller reset), the fill calms to
///   accentSubtle with a thin accent ring, and the contents cross-fade via
///   AnimatedSwitcher (fade + 8px slide, morphOut/morphIn) — the same
///   element persists across the state change, nothing unmounts.
/// - [busy]: taps are swallowed and a subtle progress spinner replaces the
///   label.
/// - **[onPressed] null: DISABLED.** The breath stops dead, the fill drops to
///   the muted surface, and taps do nothing. This is not a styling nicety — the
///   driver dashboard disables GO when a compliance document has actually
///   expired, and a button that still breathes and still swallows taps would
///   read as broken rather than as deliberate. It is never disabled without a
///   rung above it naming exactly which document, and why.
///
/// Web budget: transform + paint-alpha only; the animated stack sits inside
/// its own [RepaintBoundary]; no Opacity widget anywhere in the subtree.
class GoButton extends StatefulWidget {
  const GoButton({
    required this.onPressed,
    required this.online,
    this.busy = false,
    this.size = 168,
    super.key,
  });

  /// Fired exactly once per completed tap (never while [busy]).
  ///
  /// Null DISABLES the button: no breath, no ink, no tap. The consuming riblet
  /// owes the driver a visible reason whenever it passes null.
  final VoidCallback? onPressed;

  /// Whether the button accepts taps at all.
  bool get _enabled => onPressed != null && !busy;

  /// Offline (false) breathes the celebratory GO; online (true) is quiet.
  final bool online;

  /// Disabled + subtle progress treatment while a transition is in flight.
  final bool busy;

  /// Diameter of the main circle.
  final double size;

  @override
  State<GoButton> createState() => _GoButtonState();
}

class _GoButtonState extends State<GoButton> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _press;
  late final Animation<double> _breathScale;
  late final Animation<double> _echoScale;
  late final Animation<double> _pressScale;

  /// Pauses the breath when the app is not visible.
  ///
  /// 🔴 Web performance: a `reverse: true` repeat drives a frame every ~16ms
  /// for the whole time an idle-but-offline driver sits on "Ready to drive?".
  /// Flutter web does NOT stop a `.repeat()` controller when the tab is hidden,
  /// so the breath keeps burning main-thread frames on a page the user cannot
  /// even see. Pausing on `hidden`/`paused` (and resuming on `resumed`) stops
  /// that — the animation exists to invite a tap, and there is no one to invite
  /// while the tab is backgrounded.
  AppLifecycleListener? _lifecycle;
  bool _appVisible = true;

  static const double _breathPeak = 1.05;
  static const double _echoPeak = 1.12;
  static const double _pressDip = 0.96;
  static const double _echoAlpha = 0.18;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this);
    _press = AnimationController(vsync: this);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final visible = state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive;
        if (visible == _appVisible) return;
        _appVisible = visible;
        _syncPulse();
      },
    );
    // §5: breath 1.0→1.05, ease-in-out, reverse-repeat.
    _breathScale = Tween<double>(begin: 1, end: _breathPeak).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    // Echo scales slightly ahead of the breath — same controller, offset
    // interval, so the glow reads without any animated shadow.
    _echoScale = Tween<double>(begin: 1, end: _echoPeak).animate(
      CurvedAnimation(
        parent: _pulse,
        curve: const Interval(0, 0.85, curve: Curves.easeInOut),
      ),
    );
    _pressScale = Tween<double>(begin: 1, end: _pressDip).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.hoppin.motion;
    _pulse.duration = motion.goPulsePeriod;
    // §5: press dip ~100ms — the fade token carries the 100ms step.
    _press.duration = motion.fade;
    _syncPulse();
  }

  @override
  void didUpdateWidget(GoButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.online != widget.online ||
        (oldWidget.onPressed == null) != (widget.onPressed == null)) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    // A DISABLED button does not breathe (the breath is an invitation, and
    // there is nothing to accept), and neither does a HIDDEN app (no one is
    // there to accept it, and the frames would burn on an unseen tab).
    if (widget.online || widget.onPressed == null || !_appVisible) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  void _handleTapDown(TapDownDetails details) {
    _press.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _press.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    _press.reverse();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _pulse.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final motion = hoppin.motion;

    final disabled = widget.onPressed == null;

    // Disabled reads as DELIBERATE: a muted surface with a hairline ring, never
    // a live accent circle that silently swallows taps.
    final circleColor = disabled
        ? colors.raised
        : (widget.online ? colors.accentSubtle : colors.accent);
    final ring = disabled
        ? Border.all(color: colors.hairline, width: 2)
        : (widget.online
            ? Border.all(color: colors.accent.withValues(alpha: 0.45), width: 2)
            : null);

    final Widget content;
    if (disabled && !widget.busy) {
      content = Text(
        'GO',
        key: const ValueKey('go-disabled'),
        style: hoppin.type.display.copyWith(
          color: colors.textMid,
          letterSpacing: 1,
        ),
      );
    } else if (widget.busy) {
      content = SizedBox(
        key: const ValueKey('go-busy'),
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: widget.online ? colors.accent : colors.onAccent,
        ),
      );
    } else if (widget.online) {
      content = Column(
        key: const ValueKey('go-online'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_tethering, size: 40, color: colors.accent),
          SizedBox(height: hoppin.spacing.xs),
          Text(
            'Online',
            style: hoppin.type.label.copyWith(color: colors.accent),
          ),
        ],
      );
    } else {
      content = Text(
        'GO',
        key: const ValueKey('go-offline'),
        style: hoppin.type.display.copyWith(
          color: colors.onAccent,
          letterSpacing: 1,
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: widget._enabled,
      label: widget.online ? 'Online' : 'Go online',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget._enabled ? _handleTapDown : null,
        onTapUp: widget._enabled ? _handleTapUp : null,
        onTapCancel: _handleTapCancel,
        child: RepaintBoundary(
          child: ScaleTransition(
            scale: _pressScale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Echo circle — pre-painted low-alpha fill, glow without
                  // an animated BoxShadow. A disabled button has no glow: the
                  // halo is the invitation, and there is nothing to accept.
                  ScaleTransition(
                    scale: _echoScale,
                    child: SizedBox.expand(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accent.withValues(
                            alpha: disabled ? 0 : _echoAlpha,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ScaleTransition(
                    scale: _breathScale,
                    child: AnimatedContainer(
                      // Colour-only implicit animation (never size).
                      duration: motion.quick,
                      curve: motion.easeOut,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: circleColor,
                        border: ring,
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: motion.morphIn,
                          reverseDuration: motion.morphOut,
                          switchInCurve: motion.easeOut,
                          switchOutCurve: motion.easeOut,
                          transitionBuilder: (child, animation) {
                            // Fade + 8px rise — no Opacity widget;
                            // FadeTransition composites via paint alpha.
                            final slide = Tween<Offset>(
                              begin: const Offset(0, 0.08),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                          child: content,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
