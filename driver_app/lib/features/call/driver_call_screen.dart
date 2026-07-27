import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../dashboard/widgets/seam_unavailable_states.dart';
import 'widgets/driver_call_unavailable_state.dart';
import 'widgets/incoming_call_frame.dart';

/// Which Figma frame the layout is composing.
///
/// 🔴 THESE ARE **LAYOUTS, NOT CALL STATES.** No call exists to be in a state.
/// A frame selector — not a lifecycle — drives them, because building only the
/// frames a lifecycle could reach would leave the rest unbuilt on the day #45
/// finally lands.
enum DriverCallFrame {
  /// Figma `(calling)` — the outbound frame.
  calling,

  /// Figma `(ringing)` — the same layout, a different status line.
  ringing,

  /// Figma `(connected)` — adds the `00:00` readout + mute/speaker.
  connected,

  /// 🔴 THE DRIVER-ONLY FRAME. The rider has no incoming surface — a rider is
  /// never called BY a driver in this product. The Figma ships it
  /// (`Home - Active trip (incoming call)`) and it needs ANSWER and DECLINE
  /// controls, both INERT, both recorded by the never-dial fake.
  incoming,
}

/// OT-11 — the driver's masked in-trip voice surface, INERT on disclosed seam
/// #45.
///
/// ## What this screen does not do
///
/// **It never dials.** Not through a plugin, not through a telephone URI, not
/// through anything. The dial scheme is deliberately never spelled literally
/// anywhere in `lib/` — the phase gate greps for it, and a docstring explaining
/// the ban must not be what trips the gate.
///
/// This is not caution; it is the requirement. There is no
/// `POST /rides/:id/call` proxy and no masked-number field on any ride payload
/// (#45), so the app has no masked number to reach. With no bridge, the only
/// number the DRIVER app could reach is the RIDER'S PERSONAL one — which this
/// app must never even possess. A call button that dialled a real number would
/// not be a partial implementation of this surface; it would be its inversion.
/// The property is asserted mechanically in `never_dial_test.dart`.
///
/// ## What it does do
///
/// It renders the full designed surface — navy full-bleed, all four Figma frame
/// layouts including the driver-only incoming frame — with
/// [DriverCallUnavailableState] standing exactly where the live status line
/// would be, saying the true thing and handing the driver the comms surface that
/// actually works (chat is BOUND).
///
/// 🔴 **NO rider identity renders.** The rider's own call screen renders a
/// `RideDriverInfo` from the #5 seam — this surface has no such seam and no such
/// object. `tripRiderContext()` (#6) answers null on live, and the offer payload
/// carries coordinates and fare only. Where the Figma draws "Sarah Johnson ★4.9
/// (94 trips)", this mounts the registered [RiderContextUnavailable] rung. Not
/// one fabricated character.
///
/// The `00:00` in the connected frame is **inert layout**. No `Timer`, no
/// `AnimationController`, nothing that advances — a clock counting up would be a
/// counterfeit call duration, and `never_dial_test.dart` pins it still across
/// five pumped seconds.
class DriverCallScreen extends ConsumerStatefulWidget {
  /// Creates the inert call surface for [rideId].
  const DriverCallScreen({required this.rideId, super.key});

  /// The ride whose rider is being (not) called.
  final String rideId;

  @override
  ConsumerState<DriverCallScreen> createState() => _DriverCallScreenState();
}

class _DriverCallScreenState extends ConsumerState<DriverCallScreen> {
  /// The Figma frame currently composed. Selected by the driver, NEVER driven
  /// by a call lifecycle — there is no call lifecycle.
  DriverCallFrame _frame = DriverCallFrame.calling;

  // PUSHED, not `go`-ne to: the driver opens chat FROM the call surface and is
  // expected to come back to it. `go` would replace this route.
  void _openChat() => unawaited(context.push('/trip/${widget.rideId}/chat'));

  /// 🔴 UNCONDITIONAL EXIT. This surface is reached with `context.go`, which
  /// REPLACES rather than pushes — so a bare `pop()` has nothing on the stack to
  /// pop and does nothing, stranding the driver on a call frame that never dials.
  /// The end-call button is no escape either: it is DELIBERATELY disabled on
  /// #45. So the exit pops when there genuinely is a stack, otherwise returns to
  /// the trip this call belongs to. The rider shipped this broken.
  void _close() =>
      context.canPop() ? context.pop() : context.go('/trip/${widget.rideId}');

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final connected = _frame == DriverCallFrame.connected;
    final incoming = _frame == DriverCallFrame.incoming;

    // 🔴 THE FRAME RUNS UNDER THE PILL. This was a Column, so the bar's
    // BackdropFilter had nothing painted beneath it and its glass was a tinted
    // box (HopGlass's docstring names this exact failure). The frame now takes
    // the full viewport and the bar floats over it.
    return Scaffold(
      // The Figma call frame is navy full-bleed in both themes — a chrome-less
      // surface, not a themed page.
      backgroundColor: hoppin.colors.accent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(hoppin.spacing.gutter),
                child: Column(
                  children: [
                    // Clears the floating pill the frame now passes beneath.
                    SizedBox(height: hoppin.chrome.scrollPaddingTop),

                    // 1 — the identity slot. NO PERSON. Where the Figma draws
                    // the face and rating, the #6 rung stands instead — there
                    // is no name, rating, photo or trip count to render.
                    const _OnNavy(
                      child: KeyedSubtree(
                        key: Key('call.identity'),
                        child: RiderContextUnavailable(),
                      ),
                    ),
                    SizedBox(height: hoppin.spacing.xl),

                    // 2 — the frame selector. This is what makes all four Figma
                    // layouts reachable without a call lifecycle to drive them.
                    _FrameSelector(
                      selected: _frame,
                      onSelect: (f) => setState(() => _frame = f),
                    ),
                    SizedBox(height: hoppin.spacing.lg),

                    // 3 — the frame body. The Figma status line lives here; the
                    // #45 rung replaces it, because none of those words is true.
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          key: Key('call.frame.body.${_frame.name}'),
                          children: [
                            if (connected)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: hoppin.spacing.md,
                                ),
                                // INERT LAYOUT. No Timer, no ticking, no fake
                                // call duration — the Figma numeral, still.
                                child: Text(
                                  '00:00',
                                  key: const Key('call.connected.timer'),
                                  style: hoppin.type.numeralCaption.copyWith(
                                    color: hoppin.colors.onAccent.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            // THE MOUNT SITE for seam #45 (Group C) — on every
                            // frame.
                            _OnNavy(
                              child: KeyedSubtree(
                                key: const Key('call.rung'),
                                child: DriverCallUnavailableState(
                                  onOpenChat: _openChat,
                                ),
                              ),
                            ),
                            if (incoming) ...[
                              SizedBox(height: hoppin.spacing.xl),
                              const IncomingCallFrame(),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // 4 — the Figma control row: speaker / hangup / mute.
                    // Present at fidelity, DISABLED on the seam. Hidden on the
                    // incoming frame, which carries its own answer/decline pair.
                    if (!incoming) _CallControls(frame: _frame),
                    SizedBox(height: hoppin.spacing.md),
                  ],
                ),
              ),
            ),
          ),

          // The exit, floating over the frame. Design-system bar, unconditional
          // back intent.
          //
          // 🔴 POSITIONED, NOT Align. A non-positioned `Align` is sized to the
          // whole Stack and hit-tests all of it — above the content, that eats
          // every tap on the frame selector and the controls beneath. Bound to
          // top/left/right, it intercepts only where it paints.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _NavyChrome(
              child: HopTopBar(key: const Key('call.close'), onBack: _close),
            ),
          ),
        ],
      ),
    );
  }
}

/// Re-tones the design-system chrome for the navy full-bleed call frame.
///
/// [HopTopBar] paints itself with `colors.textHi` glyphs on the `colors.glass`
/// pane — the right thing on a normal page, wrong on this one. The surface
/// tokens it reads are swapped for the frame's own; every other token is
/// untouched. Same component, same behaviour, the frame's palette.
///
/// 🔴 **The glass is re-toned, not just the glyphs.** The pill is now genuinely
/// frosted over the navy frame, and light theme's glass is WHITE at 72% — over
/// a navy full-bleed that composites to a pale grey slab with white-ish text on
/// it, which is both ugly and unreadable. A frosted pane takes its tint from the
/// material it is cut from, and on this frame that material is navy: the fill
/// becomes a LIFTED navy (the accent, brightened toward its own foreground so
/// the pane still reads as a pane above the frame rather than a hole in it), and
/// the rim becomes a low lift of the frame's own light glyph colour.
///
/// The alpha is deliberately carried over from the token rather than re-picked:
/// this is a re-TONE, not a new material, and the one thing a call site must
/// never do is invent its own glass density.
class _NavyChrome extends StatelessWidget {
  const _NavyChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.hoppin.colors;

    // A navy pane, lifted off the navy frame so it reads as material. Same
    // translucency as the theme's own glass — only the hue is the frame's.
    final navyGlass = Color.alphaBlend(
      colors.onAccent.withValues(alpha: 0.16),
      colors.accent,
    ).withValues(alpha: colors.glass.a);

    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values.where((e) => e is! HoppinColors),
          colors.copyWith(
            card: colors.accent,
            textHi: colors.onAccent,
            glass: navyGlass,
            glassEdge: colors.onAccent.withValues(alpha: 0.22),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Renders the rung's typography legibly on the navy full-bleed frame.
class _OnNavy extends StatelessWidget {
  const _OnNavy({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return DefaultTextStyle.merge(
      style: TextStyle(color: hoppin.colors.onAccent),
      child: child,
    );
  }
}

/// The four-frame selector. Exists because there is no call lifecycle to drive
/// the frames — and building only the frames a lifecycle could reach would leave
/// the rest unbuilt when the backend lands.
class _FrameSelector extends StatelessWidget {
  const _FrameSelector({required this.selected, required this.onSelect});

  final DriverCallFrame selected;
  final ValueChanged<DriverCallFrame> onSelect;

  static const _labels = {
    DriverCallFrame.calling: 'Calling',
    DriverCallFrame.ringing: 'Ringing',
    DriverCallFrame.connected: 'Connected',
    DriverCallFrame.incoming: 'Incoming',
  };

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final onNavy = hoppin.colors.onAccent;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: hoppin.spacing.sm,
      runSpacing: hoppin.spacing.sm,
      children: [
        for (final frame in DriverCallFrame.values)
          Material(
            color: frame == selected
                ? onNavy.withValues(alpha: 0.18)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(hoppin.radii.control),
              side: BorderSide(color: onNavy.withValues(alpha: 0.24)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('call.frame.${frame.name}'),
              onTap: () => onSelect(frame),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: hoppin.spacing.md,
                  vertical: hoppin.spacing.sm,
                ),
                child: Text(
                  _labels[frame]!,
                  style: hoppin.type.labelSmall.copyWith(color: onNavy),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Speaker / hangup / mute — the Figma connected-frame control row.
///
/// Every control is **disabled**. There is no call to hang up, no microphone in
/// a call to mute, and no audio route to switch. A live-looking control that
/// silently does nothing is the exact dead-end the no-holes rule forbids, so
/// these render visibly inert.
class _CallControls extends StatelessWidget {
  const _CallControls({required this.frame});

  final DriverCallFrame frame;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final connected = frame == DriverCallFrame.connected;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (connected) ...[
          const _CircleControl(
            controlKey: Key('call.action.speaker'),
            icon: Icons.volume_up_outlined,
            tooltip: 'Speaker (unavailable — no call is connected)',
          ),
          SizedBox(width: hoppin.spacing.lg),
        ],
        const _CircleControl(
          controlKey: Key('call.action.hangup'),
          icon: Icons.call_end,
          tooltip: 'End call (unavailable — no call is connected)',
          destructive: true,
        ),
        if (connected) ...[
          SizedBox(width: hoppin.spacing.lg),
          const _CircleControl(
            controlKey: Key('call.action.mute'),
            icon: Icons.mic_none_outlined,
            tooltip: 'Mute (unavailable — no call is connected)',
          ),
        ],
      ],
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({
    required this.controlKey,
    required this.icon,
    required this.tooltip,
    this.destructive = false,
  });

  final Key controlKey;
  final IconData icon;
  final String tooltip;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final onNavy = hoppin.colors.onAccent;
    final fill = destructive
        ? hoppin.colors.error.withValues(alpha: 0.45)
        : onNavy.withValues(alpha: 0.10);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: false,
        label: tooltip,
        child: Container(
          key: controlKey,
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: Icon(icon, size: 26, color: onNavy.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}
